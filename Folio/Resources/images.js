(function() {
    function highestSrc(img) {
        const srcset = img.getAttribute('srcset') || img.getAttribute('data-srcset') || '';
        if (srcset) {
            const candidates = srcset.split(',').map(s => s.trim()).filter(Boolean);
            const last = candidates[candidates.length - 1];
            if (last) return last.split(/\s+/)[0];
        }
        return img.currentSrc || img.src || '';
    }

    function post(url) {
        if (!url) return;
        try { window.webkit?.messageHandlers?.image?.postMessage({ url }); } catch (e) {}
    }

    document.addEventListener('click', function(event) {
        const wrapper = event.target.closest('a.image, a.mw-file-description');
        if (wrapper) {
            event.preventDefault();
            const img = wrapper.querySelector('img');
            post(img ? highestSrc(img) : wrapper.href);
            return;
        }
        const img = event.target.closest('img');
        if (img && img.naturalWidth >= 80) {
            event.preventDefault();
            post(highestSrc(img));
        }
    }, true);
})();
