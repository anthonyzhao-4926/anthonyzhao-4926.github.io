# 专栏 id / 展示名，以及文章 viewable 归一
#
# 专栏 front matter 的 id 会与 Jekyll 内置 page.id（文档路径）冲突，
# 这里抄到 column_id，供模板按 id 归属文章、用 title 展示。
# 文章 viewable 缺省视为可见；不可见的不进 sitemap。

module Jekyll
  class SiteMetaGenerator < Generator
    safe true
    priority :low

    def generate(site)
      columns_by_id = index_columns(site)

      site.posts.docs.each do |post|
        normalize_viewable(post)
        assign_column_title(post, columns_by_id)
      end
    end

    private

    def index_columns(site)
      columns = site.collections['columns']
      return {} unless columns

      by_id = {}
      columns.docs.each do |doc|
        col_id = doc.data['id'].to_s.strip
        col_id = File.basename(doc.path, '.*') if col_id.empty?
        doc.data['column_id'] = col_id
        by_id[col_id] = doc.data['title'].to_s
      end
      by_id
    end

    def normalize_viewable(post)
      raw = post.data.key?('viewable') ? post.data['viewable'] : true
      visible = coerce_viewable(raw)
      post.data['viewable'] = visible
      post.data['sitemap'] = false unless visible
    end

    def coerce_viewable(value)
      return value if value == true || value == false
      return true if value.nil?

      !%w[false 0 no off].include?(value.to_s.strip.downcase)
    end

    def assign_column_title(post, columns_by_id)
      col = post.data['column']
      return if col.nil? || col.to_s.strip.empty?

      key = col.to_s.strip
      post.data['column'] = key
      post.data['column_title'] = columns_by_id[key] || key
    end
  end
end
