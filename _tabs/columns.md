---
layout: default
title: 专栏
permalink: /columns/
order: 1
---

{% assign columns = site.data.columns | sort: "order" %}
{% assign tag_pool = "" | split: "," %}
{% for c in columns %}
{% if c.tags %}
{% for t in c.tags %}
{% assign tag_pool = tag_pool | push: t %}
{% endfor %}
{% endif %}
{% endfor %}
{% assign tag_names = "" | split: "," %}
{% for t in tag_pool %}
{% unless tag_names contains t %}
{% assign tag_names = tag_names | push: t %}
{% endunless %}
{% endfor %}

<header class="page-head">
    <p class="page-kicker">专栏</p>
    <h1 class="page-title">把散落的文字，收成几册。</h1>
    <p class="page-sub">技术学习的笔记，生活随手的感悟，各自归位，各自生长。</p>
    <p class="page-meta mono">共 <em id="meta-cols">{{ columns.size }}</em> 个专栏</p>
</header>

{% if tag_names.size > 0 %}
<!-- 顶部标签条：默认显示第一行，溢出行由 columns-filter.js 折叠 -->
<div class="cls-tagbar">
    <div class="cls-tagwrap" id="tagwrap" aria-label="按主题筛选专栏">
        <button type="button" class="tag-f is-on" data-tag="all" aria-pressed="true">
            <span>全部专栏</span><span class="tag-count mono">{{ columns.size }}</span>
        </button>
        {% for t in tag_names %}
        {% assign t_count = 0 %}
        {% for c in columns %}
        {% if c.tags contains t %}
        {% assign t_count = t_count | plus: 1 %}
        {% endif %}
        {% endfor %}
        <button type="button" class="tag-f" data-tag="{{ t }}" aria-pressed="false">
            <span>{{ t }}</span><span class="tag-count mono">{{ t_count }}</span>
        </button>
        {% endfor %}
    </div>
    <button type="button" class="cls-tagmore" id="tagmore" hidden aria-expanded="false">
        更多标签<span class="caret">▾</span>
    </button>
</div>
{% endif %}

<div class="cls-list" id="clist">
    {% for column in columns %}
    {% assign col_posts = site.posts | where: "column", column.id %}
    {% assign pub_posts = col_posts | where_exp: "p", "p.viewable" %}
    {% assign col_tags = "" | split: "," %}
    {% if column.tags %}
    {% assign col_tags = column.tags %}
    {% endif %}
    <article class="cls-row" data-tags="{{ col_tags | join: ' ' }}" {% if col_posts.size > 0 and pub_posts.size == 0 %}data-viewable="false"{% endif %}>
        <div class="cls-row-main">
            <h2 class="cls-title"><a href="{{ '/columns/' | append: column.id | append: '/' | relative_url }}">{{ column.title }}</a></h2>
            <p class="cls-desc">{{ column.description }}</p>
            {% if col_tags.size > 0 %}
            <div class="cls-tagline">
                {% for t in col_tags %}
                <button type="button" class="tag-chip" data-tag="{{ t }}">{{ t }}</button>
                {% endfor %}
            </div>
            {% endif %}
        </div>
        <div class="cls-row-meta mono"><span><span class="js-count" data-count-published="{{ pub_posts | size }}" data-count-all="{{ col_posts | size }}">{{ pub_posts | size }}</span> 篇</span><span class="cls-arrow">→</span></div>
    </article>
    {% endfor %}
</div>
