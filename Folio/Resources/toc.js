(function() {
    function collectSections() {
        const headers = document.querySelectorAll('section > h2, section > h3, h2, h3');
        const seen = new Set();
        const out = [];
        headers.forEach(h => {
            const text = (h.innerText || '').trim();
            if (!text || seen.has(text)) return;
            seen.add(text);
            const anchor = h.id || h.parentElement?.id || '';
            const level = parseInt(h.tagName.substring(1), 10);
            out.push({ title: text, level, anchor });
        });
        return out;
    }

    function emit() {
        try {
            window.webkit?.messageHandlers?.toc?.postMessage(collectSections());
        } catch (e) {}
    }

    window.folioScrollToAnchor = function(anchor) {
        if (!anchor) return;
        if (anchor === '_top') {
            window.scrollTo({ top: 0, behavior: 'smooth' });
            return;
        }
        const el = document.getElementById(anchor);
        if (el) el.scrollIntoView({ behavior: 'smooth', block: 'start' });
    };

    if (document.readyState === 'loading') {
        document.addEventListener('DOMContentLoaded', emit);
    } else {
        emit();
    }
})();
