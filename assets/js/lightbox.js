/* 正文 / mermaid 图片单击放大，点遮罩空白或 Esc 关闭 */
(function () {
    'use strict';

    var overlay = document.getElementById('img-lightbox');
    var preview = document.getElementById('img-lightbox-img');
    if (!overlay || !preview) return;

    function close() {
        overlay.hidden = true;
        preview.removeAttribute('src');
        document.body.style.overflow = '';
    }

    function open(src, alt) {
        preview.setAttribute('src', src);
        preview.setAttribute('alt', alt || '');
        overlay.hidden = false;
        document.body.style.overflow = 'hidden';
    }

    function isZoomable(el) {
        if (!el || el.tagName !== 'IMG') return false;
        if (el.id === 'img-lightbox-img') return false;
        if (el.closest('a')) return false;
        return el.classList.contains('mermaid-svg')
            || !!el.closest('.post-content, .page-content');
    }

    document.addEventListener('click', function (clickEvent) {
        var img = clickEvent.target;
        if (!isZoomable(img)) return;
        var src = img.currentSrc || img.getAttribute('src');
        if (!src) return;
        clickEvent.preventDefault();
        open(src, img.getAttribute('alt') || '');
    });

    overlay.addEventListener('click', function (overlayClick) {
        if (overlayClick.target !== preview) close();
    });

    document.addEventListener('keydown', function (keyEvent) {
        if (keyEvent.key === 'Escape' && !overlay.hidden) close();
    });
})();
