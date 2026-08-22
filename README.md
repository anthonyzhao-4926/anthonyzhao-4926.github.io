# zhaoxin 的博客

基于 **GitHub Pages + Jekyll** 的个人博客，使用 [Chirpy](https://github.com/cotes2020/jekyll-theme-chirpy) 主题。

访问地址：<https://blog.zhaoxin.website>

## 目录结构

```
├── _config.yml          # 站点配置（标题、主题、分页、插件等）
├── _posts/              # 📝 博客文章（命名：YYYY-MM-DD-标题.md）
├── _tabs/               # 顶层页面（关于 / 归档 / 分类 / 标签）
├── _data/               # 站点数据（联系方式等）
├── index.html           # 首页（layout: home，自动展示文章列表）
├── Gemfile              # 本地开发依赖
└── .github/workflows/   # GitHub Actions 自动构建部署
```

## 写作流程

1. 在 `_posts/` 下新建文件，命名 `YYYY-MM-DD-标题.md`
2. 文件开头写 front matter（`title`、`date`、`categories`、`tags`）
3. `git push` 到 `main` 分支，等待 GitHub Actions 自动部署

## 本地预览

```bash
bundle install
bundle exec jekyll serve
# 访问 http://127.0.0.1:4000
```

## 更换主题

修改 `_config.yml` 中的 `remote_theme` 字段即可切换远程主题，例如：

```yaml
remote_theme: jekyll/minima
```
