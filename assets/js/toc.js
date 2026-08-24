/* 文章右侧目录：
   1) 扫描 .toc-source 的 h2/h3 生成，并随滚动高亮当前小节
   2) 专栏页额外支持左栏切换、深链与全宽 */
(function () {
    'use strict';

    var scrollHandler = null;

    function buildToc(center, list) {
        list.innerHTML = '';
        var heads = center.querySelectorAll('h2, h3');
        if (heads.length === 0) {
            var empty = document.createElement('li');
            empty.className = 'toc-empty';
            empty.textContent = '暂无目录';
            list.appendChild(empty);
            if (scrollHandler) {
                window.removeEventListener('scroll', scrollHandler);
                scrollHandler = null;
            }
            return;
        }

        heads.forEach(function (h, i) {
            if (!h.id) h.id = 'col-sec-' + i;
            var li = document.createElement('li');
            if (h.tagName === 'H3') li.className = 'sub';
            var a = document.createElement('a');
            a.href = '#' + h.id;
            a.textContent = h.textContent;
            a.title = h.textContent;   /* 悬浮展示完整标题 */
            li.appendChild(a);
            list.appendChild(li);
        });

        if (scrollHandler) window.removeEventListener('scroll', scrollHandler);
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

    var shell = document.querySelector('.column-shell');
    var postShell = document.querySelector('.post-shell');
    var wrap = shell || postShell;
    var center = document.querySelector('.toc-source');
    var list = document.getElementById('col-toc');
    if (!center || !list) return;

    if (!wrap) {
        buildToc(center, list);
        return;
    }

    if (shell) {
        var cache = {};
        var firstUrl = shell.getAttribute('data-first') || '';
        var colBase = shell.getAttribute('data-column') || location.pathname;

        function setCurrent(url) {
            shell.querySelectorAll('.col-left-list a[data-post]').forEach(function (a) {
                a.classList.toggle('current', a.getAttribute('data-post') === url);
            });
        }

        function applyPost(url, headerHtml, contentHtml, updateHistory) {
            center.innerHTML = headerHtml + contentHtml;
            buildToc(center, list);
            setCurrent(url);
            if (updateHistory !== false) {
                try {
                    history.pushState({ url: url }, '', colBase + '#/' + encodeURIComponent(url));
                } catch (pushStateErr) { /* ignore */ }
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
                    var headerEl = doc.querySelector('.post-header');
                    var contentEl = doc.querySelector('.post-content');
                    if (!headerEl || !contentEl) return;
                    cache[url] = { header: headerEl.outerHTML, content: contentEl.outerHTML };
                    applyPost(url, headerEl.outerHTML, contentEl.outerHTML, updateHistory);
                })
                .catch(function (loadPostErr) { /* 请求失败保持现状 */ });
        }

        shell.querySelectorAll('.col-left-list a[data-post]').forEach(function (a) {
            a.addEventListener('click', function (e) {
                if (a.classList.contains('current')) return;
                e.preventDefault();
                loadPost(a.getAttribute('data-post'));
            });
        });

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
    }

    var toggleBtn = document.getElementById('col-toggle');
    if (toggleBtn) {
        var savedMode = null;
        try { savedMode = localStorage.getItem('col-mode'); } catch (readModeErr) {}
        if (savedMode === 'full') wrap.classList.add('fullwidth');

        function renderToggle() {
            var full = wrap.classList.contains('fullwidth');
            var label = toggleBtn.querySelector('.label');
            if (label) label.textContent = full ? '默认' : '全宽';
            toggleBtn.setAttribute('aria-pressed', full ? 'true' : 'false');
        }
        toggleBtn.addEventListener('click', function () {
            wrap.classList.toggle('fullwidth');
            try {
                localStorage.setItem('col-mode', wrap.classList.contains('fullwidth') ? 'full' : 'default');
            } catch (saveModeErr) {}
            renderToggle();
        });
        renderToggle();
    }

    buildToc(center, list);
})();
