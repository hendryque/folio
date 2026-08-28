// didFinish waits for every subresource; the article is visually complete
// long before that. Signal after two frames, once the first layout is on
// screen, so the reader reveals at first paint instead.
(function () {
    function signal() {
        try { window.webkit.messageHandlers.painted.postMessage(1); } catch (e) {}
    }
    requestAnimationFrame(function () { requestAnimationFrame(signal); });
})();
