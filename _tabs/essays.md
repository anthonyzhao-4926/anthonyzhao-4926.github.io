---
layout: default
title: 随笔
permalink: /essays/
order: 2
---

{% assign essays = site.posts | where_exp: "post", "post.column == nil" %}
{% assign essays_published = essays | where_exp: "p", "p.viewable" %}
<header class="page-head">
    <p class="page-kicker">随笔</p>
    <h1 class="page-title">散落成篇。</h1>
    <p class="page-sub">没进专栏的单篇文字，也各自成篇。</p>
    <p class="page-meta mono">共 <em class="count-published">{{ essays_published.size }}</em><em class="count-all">{{ essays.size }}</em> 篇</p>
</header>

<div class="post-list">
    {% for post in essays %}
    <article class="post-item" data-viewable="{{ post.viewable }}">
        <div class="post-gutter">
            <span class="vdate">{{ post.date | date: "%m·%d" }}</span>
        </div>
        <div class="post-body">
            <p class="post-flag mono"><span class="flag-dot"></span>随笔{% unless post.viewable %} <span class="draft-badge">草稿</span>{% endunless %}</p>
            <h2 class="post-title"><a href="{{ post.url | relative_url }}">{{ post.title }}</a></h2>
            {% if post.excerpt %}<p class="post-excerpt">{{ post.excerpt | strip_html | truncate: 120 }}</p>{% endif %}
        </div>
    </article>
    {% endfor %}
    {% if essays.size == 0 %}
    <p class="muted">还没有随笔。</p>
    {% endif %}
</div>
