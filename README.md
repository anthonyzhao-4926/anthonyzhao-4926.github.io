# 天青·水 —— 一个自研的 Jekyll 博客框架

不依赖任何第三方主题，从零构建的 Jekyll 博客框架。支持文章、专栏、全站搜索、深浅色切换、多仓库笔记聚合，并通过 GitHub Actions 自动构建部署到 GitHub Pages。

> 本项目既是一个**可复用的博客框架**，也是作者的实际站点：[blog.zhaoxin.website](https://blog.zhaoxin.website)

## ✨ 特性

- **自研主题「天青·水」**：无第三方主题依赖，一套布局，深 / 浅双色主题
- **专栏系统**：文章可归入专栏（每篇一个专栏），专栏页面带侧边栏目录、支持手动排序
- **全站搜索**：⌘K / Ctrl+K 唤起搜索浮层，检索标题与正文
- **文章目录（TOC）**：长文自动生成目录
- **多仓库笔记聚合**：构建时从其他笔记仓库拉取内容，按提交日期合入主时间线，本地不保留副本
- **自动部署**：GitHub Actions 构建部署到 GitHub Pages，支持定时重建拉取笔记仓库最新提交
- **SEO 与站点地图**：内置 `jekyll-seo-tag` 与 `jekyll-sitemap`

## 🗂 目录结构

```
.
├── _config.yml              # 站点核心配置（标题、导航、集合、默认值）
├── _posts/                  # 📝 博客文章（命名：YYYY-MM-DD-标题.md）
│   └── notes/               # 由 scripts/pull-notes.sh 生成的外部仓库笔记（不入库）
├── _tabs/                   # 顶层页面（nav: false 的如归档页不显示在导航）
├── _columns/                # 专栏定义（每个文件 = 一个专栏）
├── _layouts/                # 布局：default / home / post / page / column
├── _includes/               # 页面片段：header / head / column-shell
├── _data/                   # 站点数据（contact.yml 社交链接）
├── assets/                  # 样式与脚本（style.css、theme.js、search.js、toc.js）
├── scripts/                 # 构建辅助脚本（pull-notes.sh、notes-repos.txt）
├── search.json              # 搜索索引数据源（Jekyll 渲染为 /search.json）
├── Gemfile                  # 本地开发依赖
└── .github/workflows/       # GitHub Actions 自动构建部署
```

## 🚀 快速开始

把本仓库当作框架模板使用：

1. **克隆**：`git clone <本仓库地址> my-blog && cd my-blog`
2. **改站点信息**：编辑 `_config.yml` 的 `title`、`tagline`、`description`、`url`
3. **本地预览**：

   ```bash
   bundle install
   bundle exec jekyll serve
   # 访问 http://127.0.0.1:4000
   ```

4. **部署**：推送到 GitHub 的 `main` 分支，GitHub Actions 自动构建并发布到 Pages。若要启用自定义域名，配置 `CNAME` 文件与 `_config.yml` 中的 `url`。

## ✍️ 写作

### 普通文章

在 `_posts/` 下新建 `YYYY-MM-DD-标题.md`：

```yaml
---
title: 我的第一篇文章
date: 2026-08-23
tags: [jekyll, 博客]
column: tech-notes   # 可选：归入某个专栏（填专栏 id，须先在 _columns/ 定义）
viewable: true       # false 为草稿，默认不展示；首页右上角可打开「草稿」开关查看
---
```

### 专栏

1. 在 `_columns/` 下新建专栏定义（`title` 用于页面展示，`id` 供文章归属，`order` 控制显示顺序）：

   ```yaml
   ---
   title: 技术学习
   id: tech-notes
   description: 技术学习与踩坑记录
   order: 2
   ---
   ```

2. 文章 front matter 里写 `column: tech-notes`（专栏 `id`）即归入该专栏（每篇一个专栏）。同专栏文章可用 `order` 手动排序（有 `order` 的排在前面，其余按时间）。

### 可见性

文章 front matter 的 `viewable` 控制是否默认出现在首页、专栏、随笔、归档和搜索里。缺省为 `true`。设为 `false` 的草稿仍会构建，首页右上角的开关可临时展示它们。

### 顶层页面

在 `_tabs/` 下新建 `.md`，front matter 里指定 `title`、`permalink`、`order`，导航栏会自动出现；设置 `nav: false` 可隐藏。

## 📚 多仓库笔记聚合

支持把任意多个其他 Git 仓库（如笔记、知识库）的内容并入本博客主时间线。采用**构建时拉取**：本地仓库不保留笔记内容，由 GitHub Actions 构建时临时 `git clone`。

### 添加仓库

编辑 `scripts/notes-repos.txt`，每行一个仓库，格式为 `名称 <空格> 地址`：

```
claude-code https://github.com/anthonyzhao-4926/claude-code.git
my-notes     https://github.com/<你的名字>/<笔记仓库>.git
```

- **名称**：作为输出子目录 `_posts/notes/<名称>/`，建议用简短英文，不含空格
- **地址**：须为公开仓库（CI 无凭据）
- 以 `#` 开头的行会被忽略，用于临时停用某个仓库
- 删除某行即移除该仓库及其笔记

### 生成逻辑

`scripts/pull-notes.sh` 会为每个仓库临时 `git clone`，遍历其中的 Markdown，按各文件在 Git 中的**提交日期**生成 front matter，输出到 `_posts/notes/<名称>/`；仓库内引用的图片同步到 `assets/notes/<名称>/`，并把相对引用改写为对应路径。全部输出物不入库（见 `.gitignore`）。

### 本地手动拉取

```bash
bash scripts/pull-notes.sh   # 会临时 clone 所有仓库并生成
```

> GitHub Actions 已配置每小时定时重建，笔记仓库 push 后最多延迟 1 小时自动上线；也可在 Actions 页面手动点击 **Run workflow** 立即触发。

## ⚙️ 配置要点

`_config.yml` 中常用的定制项：

| 配置 | 说明 |
|---|---|
| `title` / `tagline` / `description` | 站点名称与副标题，显示于首页页眉 |
| `url` | 站点域名，须与 `CNAME` 一致 |
| `paginate` | 首页每页文章数 |
| `collections.tabs` / `collections.columns` | 顶层页面与专栏集合 |
| `_data/contact.yml` | 侧边栏社交链接（github / twitter / email / rss） |
| `timezone` / `lang` | 时区与语言 |

## 🧰 本地开发常用命令

```bash
bundle exec jekyll serve        # 本地预览（默认 http://127.0.0.1:4000）
bundle exec jekyll build        # 构建到 _site/
bundle exec jekyll serve --drafts   # 预览草稿
bash scripts/pull-notes.sh      # 手动生成外部仓库笔记
```

## 📄 License

MIT
