---
layout: page
title: 归档
permalink: /archives/
order: 4
nav: false
# 按时间归档展示全部文章（按月分组）
---

{% assign grouped = site.posts | group_by_exp: "post", "post.date | date: '%Y-%m'" %}
{% for group in grouped %}
<section class="archive-month">
<h2>{{ group.name }}</h2>
<ul>
{% for post in group.items %}
<li data-viewable="{{ post.viewable }}"><a href="{{ post.url | relative_url }}">{{ post.title }}</a>{% unless post.viewable %} <span class="draft-badge">草稿</span>{% endunless %} · {{ post.date | date: "%Y-%m-%d" }}</li>
{% endfor %}
</ul>
</section>
{% endfor %}
