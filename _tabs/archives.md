---
layout: page
title: 归档
permalink: /archives/
order: 4
# 按时间归档展示全部文章（按月分组）
---

{% assign grouped = site.posts | group_by_exp: "post", "post.date | date: '%Y-%m'" %}
{% for group in grouped %}
## {{ group.name }}

{% for post in group.items %}
- [{{ post.title }}]({{ post.url | relative_url }}) · {{ post.date | date: "%Y-%m-%d" }}
{% endfor %}

{% endfor %}
