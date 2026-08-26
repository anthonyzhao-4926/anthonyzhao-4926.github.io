/* 全站搜索：读取 search.json，前端子串匹配 + 标题优先排序，无外部依赖 */
(function () {
    'use strict';

    var overlay = document.getElementById('search-overlay');
    var btn = document.getElementById('search-btn');
    var input = document.getElementById('search-input');
    var resultsEl = document.getElementById('search-results');
    var emptyEl = document.getElementById('search-empty');
    var closeBtn = document.getElementById('search-close');
    if (!overlay || !btn || !input || !resultsEl) return;

    var index = null;
    var loaded = false;

    function loadIndex() {
        if (loaded) return Promise.resolve(index);
        return fetch('/search.json')
            .then(function (r) { return r.json(); })
            .then(function (data) { index = data || []; loaded = true; return index; })
            .catch(function () { index = []; loaded = true; return index; });
    }

    function tokenize(q) {
        return q.toLowerCase().split(/[\s,，。、;；:：!！?？()（）"'“”‘’《》<>@#]+/).filter(Boolean);
    }

    function score(p, terms) {
        var s = 0;
        terms.forEach(function (t) {
            if (p.title && p.title.toLowerCase().indexOf(t) > -1) s += 10;
            if (p.excerpt && p.excerpt.toLowerCase().indexOf(t) > -1) s += 4;
            if (p.content && p.content.toLowerCase().indexOf(t) > -1) s += 1;
        });
        return s;
    }

    function esc(s) {
        return s.replace(/&/g, '&amp;').replace(/</g, '&lt;').replace(/>/g, '&gt;');
    }

    function highlight(text, terms) {
        if (!text) return '';
        var out = esc(text);
        terms.forEach(function (term) {
            var re = new RegExp('(' + term.replace(/[.*+?^${}()|[\]\\]/g, '\\$&') + ')', 'gi');
            out = out.replace(re, '<mark>$1</mark>');
        });
        return out;
    }

    function snippet(p, terms) {
        var body = p.content || '';
        var idx = -1;
        // 在全文里找第一个命中的词，取其前后文字作摘要
        for (var i = 0; i < terms.length; i++) {
            var t = terms[i];
            var j = body.toLowerCase().indexOf(t.toLowerCase());
            if (j > -1) { idx = j; break; }
        }
        if (idx > -1) {
            var start = Math.max(0, idx - 24);
            var seg = body.slice(start, start + 110);
            if (start > 0) seg = '…' + seg;
            if (start + 110 < body.length) seg += '…';
            return highlight(seg, terms);
        }
        // 只命中标题时，退回正文开头
        var fallback = (p.excerpt || body || '').slice(0, 110);
        return highlight(fallback, terms);
    }

    function render() {
        var q = input.value.trim();
        if (!q) {
            resultsEl.innerHTML = '';
            emptyEl.hidden = true;
            return;
        }
        var terms = tokenize(q);
        if (terms.length === 0) {
            resultsEl.innerHTML = '';
            emptyEl.hidden = true;
            return;
        }
        var showDrafts = document.documentElement.hasAttribute('data-show-drafts');
        var hits = (index || []).filter(function (p) {
            return showDrafts || p.viewable !== false;
        }).map(function (p) {
            return { p: p, s: score(p, terms) };
        }).filter(function (h) { return h.s > 0; }).sort(function (a, b) { return b.s - a.s; });

        if (hits.length === 0) {
            resultsEl.innerHTML = '';
            emptyEl.hidden = false;
            return;
        }
        emptyEl.hidden = true;
        resultsEl.innerHTML = hits.map(function (h) {
            var p = h.p;
            var flag = p.column || '随笔';
            var draftMark = p.viewable === false ? ' <span class="draft-badge">草稿</span>' : '';
            return '<article class="search-result">' +
                '<p class="post-flag mono"><span class="flag-dot"></span>' + esc(flag) + draftMark + '</p>' +
                '<h3 class="search-title"><a href="' + esc(p.url) + '">' + highlight(p.title, terms) + '</a></h3>' +
                '<p class="search-snippet">' + snippet(p, terms) + '</p>' +
                '</article>';
        }).join('');
    }

    var debounce = null;
    input.addEventListener('input', function () {
        clearTimeout(debounce);
        debounce = setTimeout(function () {
            loadIndex().then(render);
        }, 120);
    });

    function open() {
        overlay.hidden = false;
        document.body.style.overflow = 'hidden';
        setTimeout(function () { input.focus(); }, 60);
    }

    function close() {
        overlay.hidden = true;
        document.body.style.overflow = '';
    }

    btn.addEventListener('click', open);
    closeBtn.addEventListener('click', close);
    overlay.addEventListener('click', function (e) {
        if (e.target === overlay) close();
    });
    document.addEventListener('keydown', function (e) {
        if (e.key === 'Escape') close();
        if ((e.metaKey || e.ctrlKey) && e.key.toLowerCase() === 'k') {
            e.preventDefault();
            overlay.hidden ? open() : close();
        }
    });
    input.addEventListener('keydown', function (e) {
        if (e.key === 'Enter') {
            var first = resultsEl.querySelector('a');
            if (first) window.location.href = first.getAttribute('href');
        }
    });
})();
