/* 专栏页阅读器：
   1) 右栏「本文目录」：扫描 .toc-source 的 h2/h3 生成，并随滚动高亮当前小节
   2) 左栏文章点击：内联切换中栏正文与右栏目录，左栏目录保持不动 */
(function () {
    'use strict';

    var shell = document.querySelector('.column-shell');
    if (!shell) return;

    var center = shell.querySelector('.toc-source');
    var list = document.getElementById('col-toc');
    if (!center || !list) return;

    var cache = {};
    var firstUrl = shell.getAttribute('data-first') || '';
    var colBase = shell.getAttribute('data-column') || location.pathname;

    /* ---- 目录生成 + 滚动高亮 ---- */
    var scrollHandler = null;

    function buildToc() {
        list.innerHTML = '';
        var heads = center.querySelectorAll('h2, h3');
        heads.forEach(function (h, i) {
            if (!h.id) h.id = 'col-sec-' + i;
            var li = document.createElement('li');
            if (h.tagName === 'H3') li.className = 'sub';
            var a = document.createElement('a');
            a.href = '#' + h.id;
            a.textContent = h.textContent;
            li.appendChild(a);
            list.appendChild(li);
        });

        if (scrollHandler) window.removeEventListener('scroll', scrollHandler);
        scrollHandler = null;
        if (heads.length === 0) return;

        var items = [];
        heads.forEach(function (h, i) {
            items.push({ el: h, link: list.children[i].querySelector('a') });
        });

        scrollHandler = function () {
            var pos = window.scrollY + 140;
            var cur = -1;
            items.forEach(function (it, i) {
                if (it.el.getBoundingClientRect().top + window.scrollY <= pos) cur = i;
            });
            items.forEach(function (it, i) {
                it.link.classList.toggle('active', i === cur);
            });
        };
        window.addEventListener('scroll', scrollHandler, { passive: true });
        scrollHandler();
    }

    /* ---- 左栏当前高亮 ---- */
    function setCurrent(url) {
        shell.querySelectorAll('.col-left-list a[data-post]').forEach(function (a) {
            a.classList.toggle('current', a.getAttribute('data-post') === url);
        });
    }

    /* ---- 内联渲染到中栏 ---- */
    function applyPost(url, headerHtml, contentHtml, updateHistory) {
        center.innerHTML = headerHtml + contentHtml;
        buildToc();
        setCurrent(url);
        if (updateHistory !== false) {
            try {
                history.pushState({ url: url }, '', colBase + '#/' + encodeURIComponent(url));
            } catch (e) { /* ignore */ }
        }
        window.scrollTo({ top: 0, behavior: 'auto' });
    }

    function loadPost(url, updateHistory) {
        if (!url) return;
        if (cache[url]) {
            applyPost(url, cache[url].header, cache[url].content, updateHistory);
            return;
        }
        fetch(url)
            .then(function (r) { return r.text(); })
            .then(function (html) {
                var doc = new DOMParser().parseFromString(html, 'text/html');
                var h = doc.querySelector('.post-header');
                var c = doc.querySelector('.post-content');
                if (!h || !c) return;
                cache[url] = { header: h.outerHTML, content: c.outerHTML };
                applyPost(url, h.outerHTML, c.outerHTML, updateHistory);
            })
            .catch(function () { /* 请求失败保持现状 */ });
    }

    /* ---- 左栏点击：内联切换 ---- */
    shell.querySelectorAll('.col-left-list a[data-post]').forEach(function (a) {
        a.addEventListener('click', function (e) {
            if (a.classList.contains('current')) return;
            e.preventDefault();
            loadPost(a.getAttribute('data-post'));
        });
    });

    /* ---- 前进/后退 与 深链（#/文章URL） ---- */
    function hashUrl() {
        var m = location.hash.match(/^#\/(.+)$/);
        return m ? decodeURIComponent(m[1]) : null;
    }

    window.addEventListener('popstate', function () {
        var url = hashUrl() || firstUrl;
        if (url) loadPost(url, false);
    });

    var deep = hashUrl();
    if (deep) loadPost(deep, false);

    /* ---- 中栏全宽 / 默认 切换 ---- */
    var toggleBtn = document.getElementById('col-toggle');
    if (toggleBtn) {
        var savedMode = null;
        try { savedMode = localStorage.getItem('col-mode'); } catch (e) {}
        if (savedMode === 'full') shell.classList.add('fullwidth');

        function renderToggle() {
            var full = shell.classList.contains('fullwidth');
            var label = toggleBtn.querySelector('.label');
            if (label) label.textContent = full ? '默认' : '全宽';
            toggleBtn.setAttribute('aria-pressed', full ? 'true' : 'false');
        }
        toggleBtn.addEventListener('click', function () {
            shell.classList.toggle('fullwidth');
            try {
                localStorage.setItem('col-mode', shell.classList.contains('fullwidth') ? 'full' : 'default');
            } catch (e) {}
            renderToggle();
        });
        renderToggle();
    }

    buildToc();
})();
