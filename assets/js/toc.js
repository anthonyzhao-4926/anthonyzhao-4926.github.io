/* 文章右侧目录：
   1) 扫描 .toc-source 的 h2/h3 生成，并随滚动高亮当前小节
   2) 专栏页额外支持左栏切换、深链与贴边目录抽屉 */
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
                var isCur = a.getAttribute('data-post') === url;
                a.classList.toggle('current', isCur);
                if (isCur) {
                    var grp = a.closest('.col-group');
                    if (grp) {
                        grp.classList.remove('collapsed');
                        var head = grp.querySelector('.col-group-head');
                        if (head) head.setAttribute('aria-expanded', 'true');
                    }
                }
            });
        }

        function applyPost(url, headerHtml, contentHtml, updateHistory) {
            center.innerHTML = headerHtml + contentHtml;
            if (window.applyMermaidSvgs) window.applyMermaidSvgs(center);
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

        /* 左栏：按文件夹分组可折叠；当前文章所在组始终保持展开 */
        shell.querySelectorAll('.col-group-head').forEach(function (head) {
            head.addEventListener('click', function () {
                var grp = head.closest('.col-group');
                var collapsed = grp.classList.toggle('collapsed');
                head.setAttribute('aria-expanded', collapsed ? 'false' : 'true');
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
        else if (shell.getAttribute('data-landing') === 'true' && firstUrl) loadPost(firstUrl, false);
    }

    var leftBtn = document.getElementById('col-rail-left');
    var rightBtn = document.getElementById('col-rail-right');
    if (wrap && (leftBtn || rightBtn)) {
        var storageKey = shell ? 'col-rail-column' : 'col-rail-post';

        function readRailState() {
            try {
                var raw = localStorage.getItem(storageKey);
                return raw ? JSON.parse(raw) : { left: false, right: false };
            } catch (readRailErr) {
                return { left: false, right: false };
            }
        }

        function writeRailState(state) {
            try {
                localStorage.setItem(storageKey, JSON.stringify(state));
            } catch (writeRailErr) { /* ignore */ }
        }

        function syncButtons(state) {
            if (leftBtn) leftBtn.setAttribute('aria-expanded', state.left ? 'true' : 'false');
            if (rightBtn) rightBtn.setAttribute('aria-expanded', state.right ? 'true' : 'false');
        }

        function applyRailState(state) {
            wrap.classList.toggle('show-left', !!state.left);
            wrap.classList.toggle('show-right', !!state.right);
            syncButtons(state);
        }

        function toggleRail(side) {
            var state = readRailState();
            state[side] = !state[side];
            applyRailState(state);
            writeRailState(state);
        }

        applyRailState(readRailState());

        if (leftBtn) {
            leftBtn.addEventListener('click', function () { toggleRail('left'); });
        }
        if (rightBtn) {
            rightBtn.addEventListener('click', function () { toggleRail('right'); });
        }
    }

    buildToc(center, list);
})();
