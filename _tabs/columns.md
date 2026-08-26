---
layout: default
title: 专栏
permalink: /columns/
order: 1
---

<header class="page-head">
    <p class="page-kicker">专栏</p>
    <h1 class="page-title">把散落的文字，收成几册。</h1>
    <p class="page-sub">技术学习的笔记，生活随手的感悟，各自归位，各自生长。</p>
    <p class="page-meta mono">共 <em>{{ site.columns.size }}</em> 个专栏</p>
</header>

<div class="cls-list">
{% for column in site.columns %}
{% assign col_posts = site.posts | where: "column", column.column_id %}
{% assign pub_posts = col_posts | where_exp: "p", "p.viewable" %}
<a class="cls-row" href="{{ column.url | relative_url }}" {% if col_posts.size > 0 and pub_posts.size == 0 %}data-viewable="false"{% endif %}>
    <div class="cls-row-main">
        <h2 class="cls-title">{{ column.title }}</h2>
        <p class="cls-desc">{{ column.description }}</p>
    </div>
    <div class="cls-row-meta mono"><span><span class="count-published">{{ pub_posts.size }}</span><span class="count-all">{{ col_posts.size }}</span> 篇</span><span class="cls-arrow">→</span></div>
</a>
{% endfor %}
</div>
