// Reveal only after the faces used by the initial theme have settled. Without
// this gate the preview can cross-fade into fallback type and the article then
// reflows when the bundled fonts arrive.
(function () {
    function signal() {
        try { window.webkit.messageHandlers.painted.postMessage(1); } catch (e) {}
    }
    function afterLayout() {
        requestAnimationFrame(function () { requestAnimationFrame(signal); });
    }
    document.fonts.ready.then(afterLayout, afterLayout);
})();
