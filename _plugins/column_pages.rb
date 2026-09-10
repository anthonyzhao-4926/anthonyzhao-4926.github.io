# 专栏落地页生成器：专栏配置集中在 _data/columns.yml，
# 为每个 id 生成静态页面 /columns/<id>/（layout: column）。
#
# 落地页本身没有正文（前端按 data-first 拉取第一篇文章），
# 因此这里不依赖磁盘文件，直接构造内存中的 Page 对象。
# 不要在模板里访问 current_post.content：会触发该文带布局再渲染，
# 与 column-shell 形成递归，构建时内存暴涨、生成页大会打不开。

module Jekyll
  class ColumnPagesGenerator < Generator
    safe true
    # 高于默认优先级，确保在 sitemap 等生成器读取 site.pages 前先注入
    priority :high

    def generate(site)
      columns = site.data['columns']
      return unless columns

      columns.each do |entry|
        page = ColumnPage.new(site, entry)
        site.pages << page unless page.nil?
      end
    end
  end

  class ColumnPage < Page
    def initialize(site, entry)
      id = entry['id'].to_s.strip
      if id.empty?
        Jekyll.logger.warn('Column:', '配置中存在空 id，已跳过该专栏')
        return nil
      end

      @site      = site
      @base      = site.source
      @dir       = ''
      @name      = "#{id}.html"
      @path      = File.join(@base, 'columns', @name)
      @basename  = id
      @ext       = '.html'
      @content   = ''
      self.data  = {
        'title'       => entry['title'].to_s,
        'description' => entry['description'].to_s,
        'order'       => entry['order'],
        'column_id'   => id,
        'layout'      => 'column',
        'permalink'   => "/columns/#{id}/"
      }
    end
  end
end
