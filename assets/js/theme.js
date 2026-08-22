/* 深浅色切换：head.html 已初始化 data-theme，这里只处理按钮交互 */
(function () {
    'use strict';

    var root = document.documentElement;
    var btn = document.getElementById('theme-toggle');

    var ICON_MOON =
        '<svg viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2" stroke-linecap="round" stroke-linejoin="round"><path d="M21 12.79A9 9 0 1 1 11.21 3 7 7 0 0 0 21 12.79z"></path></svg>';
    var ICON_SUN =
        '<svg viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2" stroke-linecap="round" stroke-linejoin="round"><circle cx="12" cy="12" r="5"></circle><line x1="12" y1="1" x2="12" y2="3"></line><line x1="12" y1="21" x2="12" y2="23"></line><line x1="4.22" y1="4.22" x2="5.64" y2="5.64"></line><line x1="18.36" y1="18.36" x2="19.78" y2="19.78"></line><line x1="1" y1="12" x2="3" y2="12"></line><line x1="21" y1="12" x2="23" y2="12"></line><line x1="4.22" y1="19.78" x2="5.64" y2="18.36"></line><line x1="18.36" y1="5.64" x2="19.78" y2="4.22"></line></svg>';

    function current() {
        return root.getAttribute('data-theme');
    }

    function renderIcon() {
        if (btn) {
            btn.innerHTML = current() === 'dark' ? ICON_SUN : ICON_MOON;
        }
    }

    function setTheme(theme) {
        root.setAttribute('data-theme', theme);
        try {
            localStorage.setItem('theme', theme);
        } catch (e) {
            /* localStorage 不可用时忽略（如隐私模式） */
        }
        renderIcon();
    }

    if (btn) {
        renderIcon();
        btn.addEventListener('click', function () {
            setTheme(current() === 'dark' ? 'light' : 'dark');
        });
    }
})();
