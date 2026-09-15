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

    // The lightbox shows a bare image otherwise, with nothing saying what
    // it is. Wikipedia already wrote the caption; carry it across.
    function captionFor(el) {
        const figure = el.closest('figure');
        const caption = figure && figure.querySelector('figcaption');
        return caption ? caption.textContent.trim() : '';
    }

    function post(url, caption) {
        if (!url) return;
        try { window.webkit?.messageHandlers?.image?.postMessage({ url, caption: caption || '' }); } catch (e) {}
    }

    document.addEventListener('click', function(event) {
        // The hero is a CSS background, so there is no <img> to hit.
        const hero = event.target.closest('.folio-header[data-hero-src]');
        if (hero) {
            event.preventDefault();
            const title = hero.querySelector('.folio-title');
            post(hero.getAttribute('data-hero-src'), title ? title.textContent.trim() : '');
            return;
        }
        const wrapper = event.target.closest('a.image, a.mw-file-description');
        if (wrapper) {
            event.preventDefault();
            const img = wrapper.querySelector('img');
            post(img ? highestSrc(img) : wrapper.href, captionFor(wrapper));
            return;
        }
        const img = event.target.closest('img');
        if (img && img.naturalWidth >= 80) {
            event.preventDefault();
            post(highestSrc(img), captionFor(img));
        }
    }, true);
})();
