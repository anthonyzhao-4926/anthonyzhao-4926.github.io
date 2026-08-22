---
title: 生活随笔
description: 记录日常、感悟与碎碎念
order: 1
---

这里是我的生活随笔专栏，记录日常点滴与随想。

{% assign posts = site.posts | where: "column", page.title %}
{% assign ordered = posts | where_exp: "p", "p.order" | sort: "order" %}
{% assign rest = posts | where_exp: "p", "p.order == nil" %}
{% assign posts = ordered | concat: rest %}
{% for post in posts %}
- [{{ post.title }}]({{ post.url | relative_url }}) · {{ post.date | date: "%Y-%m-%d" }}
{% endfor %}
