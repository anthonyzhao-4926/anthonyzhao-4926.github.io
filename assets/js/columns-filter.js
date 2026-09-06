/* 专栏总览页：标签筛选 + 顶部标签条折叠（仅 /columns/ 存在 #clist 时生效） */
(function () {
    'use strict';

    var clist = document.getElementById('clist');
    var tagwrap = document.getElementById('tagwrap');
    if (!clist || !tagwrap) return;

    var tagmore = document.getElementById('tagmore');
    var metaCols = document.getElementById('meta-cols');

    var rows = Array.prototype.slice.call(clist.querySelectorAll('.cls-row'));
    var totalCols = rows.length;
    var curTag = 'all';
    var shownRows = rows.slice();
    var tagOpen = false;
    var rowH = 0;

    function tagsOf(row) {
        return (row.getAttribute('data-tags') || '').split(' ').filter(function (t) { return t; });
    }

    /* ---------- 过滤 ---------- */
    function apply() {
        var next = [];
        rows.forEach(function (row) {
            var hit = curTag === 'all' || tagsOf(row).indexOf(curTag) > -1;
            if (hit) {
                next.push(row);
                row.classList.remove('is-off');
                if (shownRows.indexOf(row) === -1) {
                    row.classList.remove('row-in');
                    void row.offsetWidth;
                    row.classList.add('row-in');
                }
            } else {
                row.classList.add('is-off');
            }
        });
        shownRows = next;

        tagwrap.querySelectorAll('.tag-f').forEach(function (b) {
            var on = b.getAttribute('data-tag') === curTag;
            b.classList.toggle('is-on', on);
            b.setAttribute('aria-pressed', on ? 'true' : 'false');
        });
        clist.querySelectorAll('.tag-chip').forEach(function (c) {
            c.classList.toggle('is-on', curTag !== 'all' && c.getAttribute('data-tag') === curTag);
        });

        if (metaCols) {
            metaCols.textContent = curTag === 'all' ? String(totalCols) : shownRows.length + ' / ' + totalCols;
        }
    }

    /* ---------- 折叠：一行放得下 → 无按钮；放不下 → 只露一行 + 「更多标签」 ---------- */
    function syncFold() {
        var first = tagwrap.querySelector('.tag-f');
        if (!first) return;
        rowH = first.offsetHeight;
        tagwrap.style.maxHeight = ''; /* 放开以便量取完整高度 */
        var overflow = tagwrap.scrollHeight > rowH + 2;
        if (!overflow) {
            if (tagmore) {
                tagmore.hidden = true;
                tagmore.classList.remove('is-open');
                tagmore.setAttribute('aria-expanded', 'false');
            }
            return;
        }
        if (!tagmore) return;
        tagmore.hidden = false;
        tagmore.innerHTML = '更多标签<span class="caret">▾</span>';
        tagmore.classList.remove('is-open');
        tagwrap.style.maxHeight = rowH + 'px';
    }

    function toggleFold() {
        if (!tagmore) return;
        tagOpen = !tagOpen;
        if (tagOpen) {
            tagwrap.style.maxHeight = tagwrap.scrollHeight + 'px';
            tagmore.innerHTML = '收起<span class="caret">▾</span>';
            tagmore.classList.add('is-open');
            tagmore.setAttribute('aria-expanded', 'true');
        } else {
            tagwrap.style.maxHeight = rowH + 'px';
            tagmore.innerHTML = '更多标签<span class="caret">▾</span>';
            tagmore.classList.remove('is-open');
            tagmore.setAttribute('aria-expanded', 'false');
        }
    }

    /* ---------- 事件：标签胶囊与行内小标签共用委托 ---------- */
    function onPick(e) {
        var el = e.target.closest ? e.target.closest('.tag-f, .tag-chip') : null;
        if (!el || !el.getAttribute('data-tag')) return;
        curTag = curTag === el.getAttribute('data-tag') ? 'all' : el.getAttribute('data-tag');
        apply();
    }

    tagwrap.addEventListener('click', onPick);
    clist.addEventListener('click', onPick);
    if (tagmore) tagmore.addEventListener('click', toggleFold);

    /* 视口变化后重新判断折叠 */
    var resizeTimer = null;
    window.addEventListener('resize', function () {
        if (resizeTimer) clearTimeout(resizeTimer);
        resizeTimer = setTimeout(function () {
            tagOpen = false;
            syncFold();
        }, 120);
    });

    syncFold();
})();
