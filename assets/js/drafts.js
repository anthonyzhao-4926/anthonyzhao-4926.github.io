/* 草稿可见性：head.html 已按 localStorage 初始化 data-show-drafts，这里处理开关 */
(function () {
    'use strict';

    var STORAGE_KEY = 'show-drafts';
    var root = document.documentElement;
    var btn = document.getElementById('drafts-toggle');

    function showing() {
        return root.hasAttribute('data-show-drafts');
    }

    function syncButton() {
        if (!btn) return;
        var on = showing();
        btn.setAttribute('aria-pressed', on ? 'true' : 'false');
        btn.classList.toggle('on', on);
    }

    function syncCounts() {
        var on = showing();
        document.querySelectorAll('.js-count').forEach(function (el) {
            var n = on ? el.getAttribute('data-count-all') : el.getAttribute('data-count-published');
            if (n != null) el.textContent = n;
        });
    }

    function setShow(on) {
        if (on) root.setAttribute('data-show-drafts', '');
        else root.removeAttribute('data-show-drafts');
        try {
            localStorage.setItem(STORAGE_KEY, on ? '1' : '0');
        } catch (saveDraftsErr) { /* localStorage 不可用时忽略 */ }
        syncButton();
        syncCounts();
    }

    syncButton();
    syncCounts();
    if (btn) {
        btn.addEventListener('click', function () {
            setShow(!showing());
        });
    }
})();
