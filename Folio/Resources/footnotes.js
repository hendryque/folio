(function() {
    function getReferenceContent(href) {
        const targetId = decodeURIComponent(href.replace('#', ''));
        const refElement = document.getElementById(targetId);
        if (!refElement) return null;
        const refText = refElement.querySelector('.reference-text, .mw-reference-text');
        return (refText || refElement).innerHTML;
    }

    function findParagraphAncestor(el) {
        let cur = el;
        for (let i = 0; i < 8 && cur && cur !== document.body; i++) {
            if (cur.tagName === 'P' || cur.tagName === 'LI' || cur.tagName === 'BLOCKQUOTE') {
                return cur;
            }
            cur = cur.parentElement;
        }
        return null;
    }

    document.addEventListener('click', function(event) {
        const link = event.target.closest('a');
        if (!link) return;
        const href = link.getAttribute('href') || '';
        if (!href.startsWith('#cite')) return;

        event.preventDefault();
        event.stopPropagation();

        const anchorEl = link.closest('sup') || link;
        const paragraph = findParagraphAncestor(anchorEl) || anchorEl;

        const next = paragraph.nextElementSibling;
        if (next && next.classList.contains('folio-footnote') && next.dataset.refid === href) {
            next.remove();
            return;
        }

        const content = getReferenceContent(href);
        if (!content) return;
        const aside = document.createElement('aside');
        aside.className = 'folio-footnote';
        aside.dataset.refid = href;
        aside.innerHTML = content;
        paragraph.insertAdjacentElement('afterend', aside);
    }, true);
})();
