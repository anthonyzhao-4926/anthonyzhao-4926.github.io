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

<div class="cols-page">
    <header class="page-head">
        <p class="page-kicker">专栏</p>
        <h1 class="page-title">把散落的文字，收成几册。</h1>
        <p class="page-sub">技术学习的笔记，生活随手的感悟，各自归位，各自生长。</p>
        <p class="page-meta mono">共 <em id="meta-cols">{{ columns.size }}</em> 个专栏</p>
    </header>

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
</div>

{% if tag_names.size > 0 %}
<!-- 标签侧栏：贴页面最左，默认收起；收起时仅保留顶部把手 -->
<aside class="side-panel" id="side-panel" aria-label="按主题筛选专栏">
    <div class="side-inner">
        <div class="side-head">
            <h2 class="side-title">主题</h2>
            <button type="button" class="side-close" id="side-close" aria-label="收起标签侧栏">
                <svg viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2" stroke-linecap="round" stroke-linejoin="round" aria-hidden="true">
                    <path d="M15 18l-6-6 6-6"></path>
                </svg>收起
            </button>
        </div>
        <p class="side-sub mono">共 {{ tag_names.size }} 个标签</p>
        <ul class="side-tags-list" id="side-list">
            <li>
                <button type="button" class="side-tag is-on" data-tag="all" aria-pressed="true">
                    <span class="side-tag-name">全部专栏</span>
                    <span class="side-tag-cnt">{{ columns.size }}</span>
                </button>
            </li>
            {% for t in tag_names %}
            {% assign t_count = 0 %}
            {% for c in columns %}
            {% if c.tags contains t %}
            {% assign t_count = t_count | plus: 1 %}
            {% endif %}
            {% endfor %}
            <li>
                <button type="button" class="side-tag" data-tag="{{ t }}" aria-pressed="false">
                    <span class="side-tag-name">{{ t }}</span><span class="side-tag-cnt">{{ t_count }}</span>
                </button>
            </li>
            {% endfor %}
        </ul>
    </div>
</aside>

<button type="button" class="rail-btn" id="side-rail" aria-expanded="false" title="展开标签筛选">
    <span>标签</span>
    <span class="rail-dot" aria-hidden="true"></span>
</button>
{% endif %}
