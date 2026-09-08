# 帖子正文 markdown 互链改写
#
# 笔记源里常用 markdown 相对链接 [text](目标.md) 互链，Jekyll 不会把它解析为
# 帖子真实 URL（/posts/<slug>/），发布后点开会 404。
# 本插件在构建阶段按「源文件名（去掉日期前缀与扩展名）」建立映射，
# 把正文中的 ](xxxx.md) 链接目标改写为目标文章的真实 URL；未命中的链接保持原样。
#
# 说明：
#   * 仅改写以 .md / .markdown 结尾的链接目标，不触碰 http(s) 链接与 /posts/ 等已有部署路径；
#   * 目标文件名允许含空格/中文/全角标点（Obsidian 常见），相对路径（./、../、dir/）按末尾文件名匹配；
#   * 同名冲突时保留第一个，避免误改写。

require 'cgi'

module Jekyll
  class MdLinksGenerator < Generator
    safe true
    priority :low

    def generate(site)
      index = build_index(site)
      return if index.empty?

      site.posts.docs.each do |doc|
        next unless doc.respond_to?(:content) && doc.content
        doc.content = rewrite(doc.content, index)
      end
    end

    private

    # key = 源文件名（去日期前缀、去扩展名），value = 真实站点 URL
    def build_index(site)
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

    def rewrite(content, index)
      content.gsub(/\]\(\s*([^()\n]*?\.(?:md|markdown))(\s*[^)\n]*?)\)/) do |match|
        target = Regexp.last_match(1).to_s.strip
        tail   = Regexp.last_match(2).to_s
        key = normalize_target(target)
        url = key && index[key]
        url ? "](#{url}#{tail})" : match
      end
    end

    # 解码 %20/%E4%B8%AD 等编码，取路径末尾文件名，去掉扩展名
    def normalize_target(target)
      decoded = CGI.unescape(target)
      name = File.basename(decoded, '.*').strip
      name.empty? ? nil : name
    end
  end
end
