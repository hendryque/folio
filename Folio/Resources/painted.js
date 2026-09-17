// didFinish waits for every subresource; the article is visually complete long
// before that. Wait only for the faces this theme paints with, then signal
// after two frames. document.fonts.ready would drag the reveal back onto the
// load event, images included.
(function () {
    function signal() {
        try { window.webkit.messageHandlers.painted.postMessage(1); } catch (e) {}
    }
    function afterLayout() {
        requestAnimationFrame(function () { requestAnimationFrame(signal); });
    }
    var queries = [];
    try {
        queries = JSON.parse(document.documentElement.getAttribute('data-font-queries')) || [];
    } catch (e) {}
    if (!queries.length) { afterLayout(); return; }
    Promise.all(queries.map(function (query) {
        return document.fonts.load(query).catch(function () {});
    })).then(afterLayout, afterLayout);
})();
