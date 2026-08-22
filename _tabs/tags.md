---
layout: page
title: 标签
permalink: /tags/
order: 3
# 自动聚合所有文章的标签（来自 front matter 的 tags 字段）
---

{% for tag in site.tags %}
- [{{ tag | first }}]({{ '/tags/' | relative_url }}{{ tag | first | slugify }}/)（{{ tag | last | size }} 篇）
{% endfor %}
