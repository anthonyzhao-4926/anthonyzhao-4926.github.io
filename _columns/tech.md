---
title: 技术学习
description: 技术学习与踩坑记录
order: 2
---

这里是我的技术学习专栏，记录学习笔记与踩坑经验。

{% assign posts = site.posts | where: "column", page.title %}
{% assign ordered = posts | where_exp: "p", "p.order" | sort: "order" %}
{% assign rest = posts | where_exp: "p", "p.order == nil" %}
{% assign posts = ordered | concat: rest %}
{% for post in posts %}
- [{{ post.title }}]({{ post.url | relative_url }}) · {{ post.date | date: "%Y-%m-%d" }}
{% endfor %}
