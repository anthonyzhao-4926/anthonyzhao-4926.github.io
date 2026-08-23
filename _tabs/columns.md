---
layout: default
title: 专栏
permalink: /columns/
order: 1
---

{% assign total_posts = site.posts.size %}
<header class="page-head">
    <p class="page-kicker">专栏</p>
    <h1 class="page-title">把散落的文字，收成几册。</h1>
    <p class="page-sub">技术学习的笔记，生活随手的感悟，各自归位，各自生长。</p>
    <p class="page-meta mono">共 <em>{{ site.columns.size }}</em> 个专栏 · <em>{{ total_posts }}</em> 篇文章</p>
</header>

<div class="cls-list">
{% for column in site.columns %}
{% assign count = site.posts | where: "column", column.title | size %}
<a class="cls-row" href="{{ column.url | relative_url }}">
    <div class="cls-row-main">
        <h2 class="cls-title">{{ column.title }}</h2>
        <p class="cls-desc">{{ column.description }}</p>
    </div>
    <div class="cls-row-meta mono"><span>{{ count }} 篇</span><span class="cls-arrow">→</span></div>
</a>
{% endfor %}
</div>
