(function() {
    function unwrap() {
        var placeholders = document.querySelectorAll('.pcs-lazy-load-placeholder');
        placeholders.forEach(function(ph) {
            // Only unwrap <span> placeholders that have a data-src
            var src = ph.getAttribute('data-src');
            if (!src) return;

            var img = document.createElement('img');
            img.src = src;

            var srcset = ph.getAttribute('data-srcset');
            if (srcset) img.srcset = srcset;

            var alt = ph.getAttribute('data-alt') || ph.getAttribute('alt') || '';
            if (alt) img.alt = alt;

            var cls = ph.getAttribute('data-class');
            if (cls) img.className = cls;

            var w = ph.getAttribute('data-width');
            if (w) img.setAttribute('width', w);
            var h = ph.getAttribute('data-height');
            if (h) img.setAttribute('height', h);

            var style = ph.getAttribute('data-style');
            if (style) img.setAttribute('style', style);

            var decoding = ph.getAttribute('data-decoding');
            if (decoding) img.decoding = decoding;

            ph.parentNode.replaceChild(img, ph);
        });
    }

    if (document.readyState === 'loading') {
        document.addEventListener('DOMContentLoaded', unwrap);
    } else {
        unwrap();
    }
})();
