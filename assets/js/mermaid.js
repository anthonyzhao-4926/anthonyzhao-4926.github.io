/* mermaid 图表主题切换
   构建时由 _plugins/mermaid.rb 渲染 light/dark 两套 SVG，
   img 无默认 src，这里按当前 data-theme 设置并跟随切换（无闪烁）。 */
(function () {
    'use strict';

    var root = document.documentElement;

    function currentTheme() {
        return root.getAttribute('data-theme') === 'dark' ? 'dark' : 'light';
    }

    function apply(imgs) {
        var theme = currentTheme();
        for (var i = 0; i < imgs.length; i++) {
            var src = imgs[i].getAttribute('data-' + theme);
            if (src && imgs[i].getAttribute('src') !== src) {
                imgs[i].setAttribute('src', src);
            }
        }
    }

    var imgs = document.querySelectorAll('img.mermaid-svg');
    apply(imgs);

    /* theme.js 只改 data-theme 属性、不派发事件，这里用 MutationObserver 跟随 */
    if ('MutationObserver' in window) {
        var observer = new MutationObserver(function (mutations) {
            for (var i = 0; i < mutations.length; i++) {
                if (mutations[i].attributeName === 'data-theme') {
                    apply(document.querySelectorAll('img.mermaid-svg'));
                    break;
                }
            }
        });
        observer.observe(root, { attributes: true, attributeFilter: ['data-theme'] });
    }
})();
