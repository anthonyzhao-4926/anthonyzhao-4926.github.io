/* 专栏总览页：左侧标签侧栏（默认收起）+ 标签过滤（仅 /columns/ 存在 #side-panel 时生效） */
(function () {
    'use strict';

    var panel = document.getElementById('side-panel');
    var rail = document.getElementById('side-rail');
    var closeBtn = document.getElementById('side-close');
    var clist = document.getElementById('clist');
    if (!panel || !rail || !closeBtn || !clist) return;

    var sideList = document.getElementById('side-list');
    var metaCols = document.getElementById('meta-cols');

    var rows = Array.prototype.slice.call(clist.querySelectorAll('.cls-row'));
    var totalCols = rows.length;
    var curTag = 'all';
    var shownRows = rows.slice();

    function tagsOf(row) {
        return (row.getAttribute('data-tags') || '').split(' ').filter(function (t) { return t; });
    }

    /* ---------- 侧栏展开 / 收起 ---------- */
    function openSide() {
        document.body.classList.add('side-open');
        rail.setAttribute('aria-expanded', 'true');
        rail.title = '收起标签筛选';
    }

    function closeSide() {
        document.body.classList.remove('side-open');
        rail.setAttribute('aria-expanded', 'false');
        rail.title = '展开标签筛选';
    }

    rail.addEventListener('click', openSide);
    closeBtn.addEventListener('click', closeSide);
    document.addEventListener('keydown', function (e) {
        if (e.key === 'Escape') closeSide();
    });

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

        if (sideList) {
            sideList.querySelectorAll('.side-tag').forEach(function (b) {
                var on = b.getAttribute('data-tag') === curTag;
                b.classList.toggle('is-on', on);
                b.setAttribute('aria-pressed', on ? 'true' : 'false');
            });
        }
        clist.querySelectorAll('.tag-chip').forEach(function (c) {
            c.classList.toggle('is-on', curTag !== 'all' && c.getAttribute('data-tag') === curTag);
        });

        if (metaCols) {
            metaCols.textContent = curTag === 'all' ? String(totalCols) : shownRows.length + ' / ' + totalCols;
        }
        rail.classList.toggle('has-filter', curTag !== 'all');
    }

    function onPick(e) {
        var el = e.target.closest ? e.target.closest('.side-tag, .tag-chip') : null;
        if (!el || !el.getAttribute('data-tag')) return;
        curTag = curTag === el.getAttribute('data-tag') ? 'all' : el.getAttribute('data-tag');
        apply();
    }

    if (sideList) sideList.addEventListener('click', onPick);
    clist.addEventListener('click', onPick);
})();
