---
layout: page
title: 分类
permalink: /categories/
order: 2
# 自动聚合所有文章的分类（来自 front matter 的 categories 字段）
---

{% for category in site.categories %}
- [{{ category | first }}]({{ '/categories/' | relative_url }}{{ category | first | slugify }}/)（{{ category | last | size }} 篇）
{% endfor %}
