---
layout: default
title: 专栏
permalink: /columns/
order: 1
---

{% assign columns = site.data.columns | sort: "order" %}

<div class="cols-page">
    <header class="page-head">
        <p class="page-kicker">专栏</p>
        <h1 class="page-title">把散落的文字，收成几册。</h1>
        <p class="page-sub">技术学习的笔记，生活随手的感悟，各自归位，各自生长。</p>
        <p class="page-meta mono">共 <em id="meta-cols">{{ columns.size }}</em> 个专栏</p>
    </header>

    <div class="cols-cards">
        {% for column in columns %}
        {% assign col_posts = site.posts | where: "column", column.id %}
        {% assign pub_posts = col_posts | where_exp: "p", "p.viewable" %}
        <a class="cols-card" href="{{ '/columns/' | append: column.id | append: '/' | relative_url }}"{% if col_posts.size > 0 and pub_posts.size == 0 %} data-viewable="false"{% endif %}>
            <span class="cols-card-top">
                <h2>{{ column.title }}</h2>
                <span class="n mono"><span class="js-count" data-count-published="{{ pub_posts | size }}" data-count-all="{{ col_posts | size }}">{{ pub_posts | size }}</span> 篇</span>
            </span>
            {% if column.description and column.description != "" %}
            <p>{{ column.description }}</p>
            {% endif %}
        </a>
        {% endfor %}
    </div>
</div>
