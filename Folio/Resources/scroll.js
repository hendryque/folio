(function() {
    var lastReported = 0;
    var debounce = null;

    function emit() {
        var y = window.scrollY || window.pageYOffset || 0;
        if (Math.abs(y - lastReported) < 30) return;
        lastReported = y;
        try {
            window.webkit?.messageHandlers?.scroll?.postMessage({ y: y });
        } catch (e) {}
    }

    window.addEventListener('scroll', function() {
        if (debounce) clearTimeout(debounce);
        debounce = setTimeout(emit, 250);
    }, { passive: true });

    // Native calls this after didFinish if there's a saved position.
    window.folioRestoreScroll = function(y) {
        if (typeof y !== 'number' || y <= 0) return;
        // Wait for layout to settle, then jump
        requestAnimationFrame(function() {
            window.scrollTo(0, y);
            lastReported = y;
        });
    };
})();
