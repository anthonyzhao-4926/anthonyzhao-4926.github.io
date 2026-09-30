/* 文章右侧目录：
   1) 扫描 .toc-source 的 h2/h3 生成，并随滚动高亮当前小节
   2) 专栏页额外支持左栏切换、深链与贴边目录抽屉 */
(function () {
    'use strict';

    var scrollHandler = null;
    var pinnedLink = null;
    var ignoreProgrammaticScroll = false;

    function maxScrollY() {
        return Math.max(0, document.documentElement.scrollHeight - window.innerHeight);
    }

    function padLastHeading(center) {
        var heads = center.querySelectorAll('h2, h3');
        if (!heads.length) return;
        var last = heads[heads.length - 1];
        var spacer = center.querySelector('.toc-end-spacer');
        if (!spacer) {
            spacer = document.createElement('div');
            spacer.className = 'toc-end-spacer';
            spacer.setAttribute('aria-hidden', 'true');
            center.appendChild(spacer);
        }
        spacer.style.height = '0px';
        var margin = parseFloat(window.getComputedStyle(last).scrollMarginTop) || 96;
        var lastTop = last.getBoundingClientRect().top + window.pageYOffset;
        var extra = lastTop - margin - maxScrollY();
        spacer.style.height = (extra > 0 ? extra : 0) + 'px';
    }

    function scrollToSection(id) {
        var target = document.getElementById(id);
        if (!target) return;
        var margin = parseFloat(window.getComputedStyle(target).scrollMarginTop) || 0;
        var top = target.getBoundingClientRect().top + window.pageYOffset - margin;
        if (top < 0) top = 0;
        var root = document.documentElement;
        var prev = root.style.scrollBehavior;
        root.style.scrollBehavior = 'auto';
        ignoreProgrammaticScroll = true;
        window.scrollTo(0, Math.min(top, maxScrollY()));
        root.style.scrollBehavior = prev;
        requestAnimationFrame(function () {
            requestAnimationFrame(function () {
                ignoreProgrammaticScroll = false;
            });
        });
    }

    function bindTocClicks(listEl, columnShell, colBase) {
        listEl.addEventListener('click', function (tocClick) {
            var a = tocClick.target.closest('a');
            if (!a || !listEl.contains(a)) return;
            var href = a.getAttribute('href');
            if (!href || href.charAt(0) !== '#') return;
            var id = href.slice(1);
            if (!id) return;
            tocClick.preventDefault();
            pinnedLink = a;
            scrollToSection(id);
            listEl.querySelectorAll('a.active').forEach(function (link) {
                link.classList.remove('active');
            });
            a.classList.add('active');
            /* 专栏 SPA 用 #/posts/... 存当前文，目录锚点不能改掉 hash，否则会误载第一篇 */
            if (columnShell && history.state && history.state.url) {
                try {
                    history.replaceState(
                        history.state,
                        '',
                        colBase + '#/' + encodeURIComponent(history.state.url)
                    );
                } catch (replaceHashErr) { /* ignore */ }
            }
        });
    }

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
            if (ignoreProgrammaticScroll) return;
            pinnedLink = null;
            var pos = window.scrollY + 140;
            var cur = -1;
            items.forEach(function (it, i) {
                if (it.el.getBoundingClientRect().top + window.scrollY <= pos) cur = i;
            });
            var last = items[items.length - 1];
            if (last) {
                var lastTop = last.el.getBoundingClientRect().top + window.scrollY;
                var maxY = maxScrollY();
                if (lastTop > maxY + 140 && window.scrollY >= maxY - 2) {
                    cur = items.length - 1;
                }
            }
            items.forEach(function (it, i) {
                it.link.classList.toggle('active', i === cur);
            });
        };
        window.addEventListener('scroll', scrollHandler, { passive: true });
        padLastHeading(center);
        scrollHandler();
    }

    var shell = document.querySelector('.column-shell');
    var postShell = document.querySelector('.post-shell');
    var wrap = shell || postShell;
    var center = document.querySelector('.toc-source');
    var list = document.getElementById('col-toc');
    if (!center || !list) return;

    bindTocClicks(list, shell, shell ? (shell.getAttribute('data-column') || location.pathname) : '');

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
            var url = hashUrl();
            if (url) {
                loadPost(url, false);
                return;
            }
            if (firstUrl) loadPost(firstUrl, false);
        });

        window.addEventListener('hashchange', function () {
            var post = hashUrl();
            if (post) {
                loadPost(post, false);
                return;
            }
            var frag = location.hash.slice(1);
            if (frag.indexOf('col-sec-') === 0) {
                scrollToSection(frag);
                if (history.state && history.state.url) {
                    try {
                        history.replaceState(
                            history.state,
                            '',
                            colBase + '#/' + encodeURIComponent(history.state.url)
                        );
                    } catch (restoreHashErr) { /* ignore */ }
                }
            }
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
            if (leftBtn) {
                leftBtn.setAttribute('aria-expanded', state.left ? 'true' : 'false');
                leftBtn.setAttribute('aria-label', state.left ? '隐藏专栏目录' : '显示专栏目录');
                leftBtn.title = state.left ? '隐藏专栏目录' : '显示专栏目录';
            }
            if (rightBtn) {
                rightBtn.setAttribute('aria-expanded', state.right ? 'true' : 'false');
                rightBtn.setAttribute('aria-label', state.right ? '隐藏本文目录' : '显示本文目录');
                rightBtn.title = state.right ? '隐藏本文目录' : '显示本文目录';
            }
        }

        function applyRailState(state) {
            wrap.classList.toggle('show-left', !!state.left);
            wrap.classList.toggle('show-right', !!state.right);
            syncButtons(state);
            padLastHeading(center);
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
    window.addEventListener('resize', function () {
        padLastHeading(center);
    });
})();
