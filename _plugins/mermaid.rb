# 服务端渲染 mermaid 图表
#
# 构建时调用 mermaid-cli（mmdc，需 npm install 安装到 node_modules）把文章里的
# ```mermaid 代码块渲染为 light / dark 两套 SVG（放在 _site/assets/mermaid/ 下），
# 并替换为 <img class="mermaid-svg" data-light data-dark>，由 assets/js/mermaid.js
# 按站点主题切换显示。
#
# 渲染放在 :site, :post_write hook 执行：Jekyll 构建末尾的 cleanup 会删除
# _site 中不在其输出清单里的文件，若在 post_render 阶段直接写 SVG 会被误删。
#
# 未安装 mmdc 时降级：打印警告并保留原始代码块，不影响其他内容构建。
# 严格模式（MERMAID_FAIL_ON_ERROR=1，CI 构建启用）：渲染失败直接使构建失败，
# 避免部署缺图页面；本地开发不设该变量，保持警告降级。

require 'cgi'
require 'fileutils'
require 'open3'
require 'tmpdir'

module Jekyll
  module MermaidServerSide
    # kramdown 输出的 fenced code block 结构（rouge 对未知语言原样输出）
    CODE_BLOCK = %r{<pre><code class="[^"]*language-mermaid[^"]*">(.*?)</code></pre>}m

    # mermaid 配置（与站点字体保持一致，见同目录 mermaid.config.json）
    CONFIG = File.join(__dir__, 'mermaid.config.json')
    # 写入 SVG 的补充样式：放开 label overflow，避免右侧文字被边框裁掉
    CSS = File.join(__dir__, 'mermaid.css')
    # puppeteer 启动配置（--no-sandbox 等，CI 环境必需，见同目录 puppeteer.config.json）
    PUPPETEER_CONFIG = File.join(__dir__, 'puppeteer.config.json')
    # CJK 字宽常被低估，导出后再给标签盒 / 节点轮廓补的水平余量（像素）
    LABEL_PAD_X = 24

    # 严格模式：渲染失败即构建失败（GitHub Actions 设置）
    STRICT = ENV['MERMAID_FAIL_ON_ERROR'] == '1'

    # 待渲染队列：post_render 时收集，post_write 时统一渲染
    PENDING = []
    # 本次构建渲染失败的图表（严格模式下用于汇总报错）
    FAILED = []

    class << self
      # 提取代码块并替换为 img 标签（不在此处渲染 SVG）
      def collect(doc)
        output = doc.output
        return if output.nil? || !output.include?('language-mermaid')

        site = doc.site
        unless find_mmdc(site)
          Jekyll.logger.warn 'Mermaid:', '未找到 mmdc (mermaid-cli)，跳过图表渲染（保留代码块）。请先在项目根目录执行 npm install'
          return
        end

        slug = sanitize_slug(doc.data['slug'] || File.basename(doc.path, File.extname(doc.path)))
        index = 0
        doc.output = output.gsub(CODE_BLOCK) do |match|
          index += 1
          PENDING << { site: site, slug: slug, index: index, code: CGI.unescapeHTML(Regexp.last_match(1)) }
          img_tag(site, slug, index)
        end
      end

      # 渲染待处理图表（post_write 阶段，_site 已就绪且不会再被 cleanup）
      def flush(site)
        items = PENDING.select { |item| item[:site] == site }
        PENDING.reject! { |item| item[:site] == site }
        return if items.empty?

        FAILED.clear
        mmdc = find_mmdc(site)
        items.each { |item| render_one(site, mmdc, item) }
        return unless STRICT && !FAILED.empty?

        raise "Mermaid 渲染失败: #{FAILED.join(', ')}（详见 _site/assets/mermaid/mermaid-error.log）"
      end

      private

      def render_one(site, mmdc, item)
        base = "#{item[:slug]}-#{item[:index]}"
        dir = File.join(site.dest, 'assets', 'mermaid')
        FileUtils.mkdir_p(dir)
        light = File.join(dir, "#{base}.light.svg")
        dark = File.join(dir, "#{base}.dark.svg")
        # 已生成过则跳过（serve 反复重建时避免重复启动 Chromium）
        return if File.exist?(light) && File.exist?(dark)

        tmp = File.join(Dir.tmpdir, "mermaid-#{base}-#{Process.pid}.mmd")
        File.write(tmp, item[:code])
        # 重试一次：Chromium 启动偶发崩溃（如 macOS 沙箱/资源紧张）时提高成功率
        ok = run_mmdc(mmdc, tmp, light, 'neutral') || run_mmdc(mmdc, tmp, light, 'neutral')
        ok &&= (run_mmdc(mmdc, tmp, dark, 'dark') || run_mmdc(mmdc, tmp, dark, 'dark'))
        File.delete(tmp) if File.exist?(tmp)
        return if ok

        Jekyll.logger.warn 'Mermaid:', "渲染失败 #{base}，页面中对应图表将缺失"
        FAILED << base
        # 错误日志写入部署产物，便于线上排查（见 /assets/mermaid/mermaid-error.log）
        log = File.join(dir, 'mermaid-error.log')
        File.open(log, 'a') do |f|
          f.puts "[#{Time.now}] #{base}: light=#{File.exist?(light)} dark=#{File.exist?(dark)}"
        end
      end

      def img_tag(site, slug, index)
        url = File.join('/', site.baseurl.to_s, 'assets', 'mermaid', "#{slug}-#{index}")
        %(<img class="mermaid-svg" data-light="#{url}.light.svg" data-dark="#{url}.dark.svg" alt="mermaid 图表" loading="lazy">)
      end

      def find_mmdc(site)
        local = File.join(site.source, 'node_modules', '.bin', 'mmdc')
        return local if File.executable?(local)

        # 回退到 PATH 中的 mmdc（如全局安装）
        return 'mmdc' if system('command -v mmdc > /dev/null 2>&1')
        nil
      end

      def run_mmdc(mmdc, input, output, theme)
        cmd = [mmdc, '-i', input, '-o', output,
               '-b', 'transparent', '-t', theme,
               '-c', CONFIG, '-p', PUPPETEER_CONFIG, '-C', CSS, '--quiet']
        _stdout, stderr, status = Open3.capture3(*cmd)
        unless status.success?
          Jekyll.logger.warn 'Mermaid:', "渲染失败 #{File.basename(output)}（#{theme}）:\n#{stderr}"
          return false
        end
        unclip_svg_labels(output)
        Jekyll.logger.info 'Mermaid:', "生成 #{File.basename(output)}"
        true
      end

      # mermaid 量字偏窄时，foreignObject / 节点轮廓会裁掉右侧末字。
      # 加宽标签盒并左移 translate，使文字仍居中；矩形节点同步加宽；
      # 圆角（stadium）用 path 描边，水平略放大以免弧边切字。
      def unclip_svg_labels(path)
        return unless File.file?(path)

        extra = LABEL_PAD_X
        half = extra / 2.0
        svg = File.read(path, encoding: 'UTF-8')

        svg.gsub!(/<g class="label"[^>]*>.*?<\/g>/m) do |group|
          fo_width = group[/<foreignObject\b[^>]*\bwidth="([\d.]+)"/, 1]
          next group if fo_width.nil? || fo_width.to_f <= 0

          widened = group.sub(/(<foreignObject\b[^>]*\bwidth=")([\d.]+)(")/) do
            format('%s%s%s', Regexp.last_match(1), Regexp.last_match(2).to_f + extra, Regexp.last_match(3))
          end
          widened.sub(/(transform="translate\()(-?[\d.]+)(,\s*-?[\d.]+\))/) do
            format('%s%s%s', Regexp.last_match(1), Regexp.last_match(2).to_f - half, Regexp.last_match(3))
          end
        end

        svg.gsub!(/<rect class="basic label-container"([^>]*)\/?>/) do |match|
          attrs = Regexp.last_match(1).sub(%r{/\s*\z}, '')
          width = attrs[/\bwidth="([\d.]+)"/, 1]
          x_pos = attrs[/\bx="(-?[\d.]+)"/, 1]
          next match if width.nil? || x_pos.nil?

          extra_w = extra
          height = attrs[/\bheight="([\d.]+)"/, 1]
          extra_w += height.to_f if attrs.include?('rx=') && height
          updated = attrs.sub(/\bwidth="[\d.]+"/, %(width="#{width.to_f + extra_w}"))
          updated = updated.sub(/\bx="-?[\d.]+"/, %(x="#{x_pos.to_f - extra_w / 2.0}"))
          %(<rect class="basic label-container"#{updated}/>)
        end

        svg.gsub!(/<g class="basic label-container outer-path"(?! transform="scale)/) do
          '<g class="basic label-container outer-path" transform="scale(1.22, 1)"'
        end

        svg.sub!(/\bviewBox="(-?[\d.]+)\s+(-?[\d.]+)\s+([\d.]+)\s+([\d.]+)"/) do
          min_x = Regexp.last_match(1).to_f - extra
          min_y = Regexp.last_match(2)
          view_w = Regexp.last_match(3).to_f + extra * 2
          view_h = Regexp.last_match(4)
          %(viewBox="#{min_x} #{min_y} #{view_w} #{view_h}")
        end

        svg.sub!(/max-width:\s*([\d.]+)px/) do
          format('max-width: %spx', Regexp.last_match(1).to_f + extra * 2)
        end

        File.write(path, svg)
      end

      def sanitize_slug(slug)
        cleaned = slug.to_s.gsub(/[^\w.-]+/, '-').gsub(/\A-+|-+\z/, '')
        cleaned.empty? ? 'page' : cleaned
      end
    end
  end
end

Jekyll::Hooks.register :posts, :post_render do |doc|
  Jekyll::MermaidServerSide.collect(doc)
end

Jekyll::Hooks.register :pages, :post_render do |doc|
  Jekyll::MermaidServerSide.collect(doc)
end

Jekyll::Hooks.register :documents, :post_render do |doc|
  Jekyll::MermaidServerSide.collect(doc)
end

Jekyll::Hooks.register :site, :post_write do |site|
  Jekyll::MermaidServerSide.flush(site)
end
