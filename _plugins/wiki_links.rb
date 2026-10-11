# 帖子正文 markdown 互链改写（.md 文章互链 + .html/.htm 文档直链）
#
# 笔记源里常用 markdown 相对链接互链：
#   * [另一篇](../../../dsh%20插件开发学习/10-事件进阶.md)  —— 指向 .md 笔记
#   * [事件生命周期](参考/事件生命周期.html)                —— 指向 HTML 参考文档
# Jekyll 不会把这两种相对路径解析成部署后的真实地址：文章页 URL 是 /posts/<slug>/，
# 浏览器按它解析相对链接，会得到 /posts/<slug>/参考/xxx.html 这类不存在的路径 → 404。
#
# 本插件在渲染前改写正文里的这两种链接：
#   * .md / .markdown → 目标文章的真实 URL /posts/<slug>/（按源文件名建索引）
#   * .html / .htm    → 目标文档的静态资源 URL（按 front matter 的 html_url 建索引）
# 未命中索引的链接（外链、站内绝对路径、非笔记文件）保持原样。
#
# 说明：
#   * 目标文件名允许含空格/中文/全角标点（Obsidian 常见），相对路径（./、../、dir/）
#     优先按完整路径后缀匹配，退化时按末尾文件名匹配；
#   * 同名冲突且无法消歧时不动，避免误改写；
#   * 输出 URL 逐段百分号编码（空格→%20、中文→%XX），保证 href 里不出现裸空格。

require 'erb'

module Jekyll
  class NoteLinksGenerator < Generator
    safe true
    priority :low

    # 已是站内绝对路径 / 外链 / 锚点，不参与改写
    ABSOLUTE = %r{\A(?:\/|\#|//|[a-z][a-z0-9+.\-]*:)}i

    def generate(site)
      md_index = build_md_index(site)
      html_index = build_html_index(site)
      return if md_index.empty? && html_index.empty?

      site.posts.docs.each do |doc|
        next unless doc.respond_to?(:content) && doc.content

        doc.content = rewrite(doc.content, md_index, html_index)
      end
    end

    private

    # ── 索引 ──────────────────────────────────────────────
    # .md：key = 源文件名（去日期前缀、去扩展名），value = 文章真实 URL
    def build_md_index(site)
      map = {}
      site.posts.docs.each do |doc|
        base = File.basename(doc.path, '.*')
        name = base.sub(/\A\d{4}-\d{2}-\d{2}-/, '').strip
        next if name.empty?
        next if map.key?(name) # 同名冲突：保留第一个

        map[name] = site.baseurl.to_s + doc.url
      end
      map
    end

    # .html/.htm：把带 html_url 的文章收集成候选（保留路径分段以便消歧）
    def build_html_index(site)
      entries = []
      site.posts.docs.each do |doc|
        url = doc.data['html_url'].to_s.strip
        next if url.empty?

        decoded = decode_path(url)
        name = File.basename(decoded, '.*')
        next if name.empty?

        entries << {
          name: name,
          segs: decoded.sub(%r{\A/+}, '').split('/'),
          url: site.baseurl.to_s + encode_path(decoded)
        }
      end
      entries
    end

    # ── 改写 ──────────────────────────────────────────────
    def rewrite(content, md_index, html_index)
      content = rewrite_links(content, /\.(?:md|markdown)/i) do |target|
        md_index[basename_key(target)]
      end
      rewrite_links(content, /\.(?:html|htm)/i) do |target|
        lookup_html(target, html_index)
      end
    end

    def rewrite_links(content, ext_re, &resolver)
      content.gsub(/\]\(\s*([^()\n]*?#{ext_re})(\s*[^)\n]*?)\)/) do
        target = Regexp.last_match(1).to_s.strip
        tail   = Regexp.last_match(2).to_s
        url = ABSOLUTE.match?(target) ? nil : resolver.call(target)
        url ? "](#{url}#{tail})" : Regexp.last_match(0)
      end
    end

    # 按完整相对路径后缀优先匹配，其次按文件名匹配；无法唯一确定时不动
    def lookup_html(target, entries)
      return nil if entries.empty?

      decoded = decode_path(target)
      segs = decoded.split('/').reject { |s| s == '.' || s.empty? }
      name = File.basename(decoded, '.*')
      return nil if name.empty?

      by_name = entries.select { |e| e[:name] == name }
      return nil if by_name.empty?

      if segs.size > 1
        exact = by_name.select { |e| e[:segs].last(segs.size) == segs }
        return exact.first[:url] if exact.size == 1
      end

      by_name.size == 1 ? by_name.first[:url] : nil
    end

    def basename_key(target)
      name = File.basename(decode_path(target), '.*').strip
      name.empty? ? nil : name
    end

    # ── 路径编解码 ────────────────────────────────────────
    # 只还原 %XX（不用 CGI.unescape，免得文件名里的 + 被当成空格）
    def decode_path(path)
      decoded = path.gsub(/%([0-9A-Fa-f]{2})/) { [Regexp.last_match(1).hex].pack('C') }
      decoded.force_encoding(Encoding::UTF_8).scrub
    end

    # 逐段编码，保留 / 分隔符（空格→%20、中文→%XX）
    def encode_path(path)
      path.split('/').map { |seg| ERB::Util.url_encode(seg) }.join('/')
    end
  end
end
