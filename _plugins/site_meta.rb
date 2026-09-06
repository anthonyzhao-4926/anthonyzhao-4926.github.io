# 文章 viewable 归一 + 专栏标题补充
#
# 专栏配置集中在 _data/columns.yml（落地页由 _plugins/column_pages.rb 生成），
# 这里把文章 front matter 的 column id 映射成展示用的 column_title。
# viewable 缺省视为可见；不可见的不进 sitemap。

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
      columns = site.data['columns']
      return {} unless columns

      by_id = {}
      columns.each do |col|
        col_id = col['id'].to_s.strip
        by_id[col_id] = col['title'].to_s unless col_id.empty?
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
