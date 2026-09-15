(function() {
    // Wikipedia hard-codes template colours in infoboxes. Strip those, but
    // keep geometry: location maps, collapsed rows and hidden scaffolding are
    // all built from inline position, size, display and visibility.
    var DROP_PROPERTY = /^(color|background|background-color|background-image|border-color|font-family|box-shadow|outline)$/;
    var BORDER_SHORTHAND = /^border(-top|-right|-bottom|-left)?$/;
    var BORDER_STYLE = /^(none|hidden|dotted|dashed|solid|double|groove|ridge|inset|outset)$/;
    var BORDER_WIDTH = /^(thin|medium|thick|[0-9.]+(px|em|rem|pt|ex|ch|vw|vh)?)$/;

    // Emit longhands rather than the shorthand: a shorthand resets
    // border-color to currentColor, which is near-black text, and being
    // inline it would beat the divider tone our CSS supplies.
    function borderLonghands(property, value) {
        var width = '', style = '';
        value.split(/\s+/).forEach(function(token) {
            var t = token.toLowerCase();
            if (BORDER_STYLE.test(t)) { style = t; }
            else if (BORDER_WIDTH.test(t)) { width = t; }
        });
        var out = [];
        if (width) out.push(property + '-width: ' + width);
        if (style) out.push(property + '-style: ' + style);
        return out;
    }

    function cleanInfoboxStyles() {
        document.querySelectorAll('.infobox [style]').forEach(function(el) {
            var kept = [];
            el.getAttribute('style').split(';').forEach(function(declaration) {
                var split = declaration.indexOf(':');
                if (split < 0) return;
                var property = declaration.slice(0, split).trim().toLowerCase();
                var value = declaration.slice(split + 1).trim();
                if (!property || !value) return;
                if (DROP_PROPERTY.test(property)) return;
                if (BORDER_SHORTHAND.test(property)) {
                    kept.push.apply(kept, borderLonghands(property, value));
                    return;
                }
                kept.push(property + ': ' + value);
            });
            if (kept.length) {
                el.setAttribute('style', kept.join('; '));
            } else {
                el.removeAttribute('style');
            }
        });
    }

    function unwrap() {
        cleanInfoboxStyles();
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
