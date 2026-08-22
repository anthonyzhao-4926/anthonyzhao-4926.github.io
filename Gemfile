# 本地开发依赖（仅本地预览需要安装）
# GitHub Pages 部署使用 .github/workflows/jekyll-gh-pages.yml 自带环境，无需本文件
source "https://rubygems.org"

gem "jekyll", "~> 4.3"

group :jekyll_plugins do
  gem "jekyll-remote-theme", "~> 0.4"
  gem "jekyll-paginate", "~> 1.1"
  gem "jekyll-sitemap", "~> 1.4"
  gem "jekyll-seo-tag", "~> 2.8"
  gem "jekyll-feed", "~> 0.17"
  gem "jekyll-redirect-from", "~> 0.16"
end

# Ruby 3.0+ 不再内置 webrick，本地 serve 需要
gem "webrick", "~> 1.8"
