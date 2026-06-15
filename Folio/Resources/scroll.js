(function() {
    var lastReported = 0;
    var rafScheduled = false;
    var endTimer = null;

    function emit() {
        var y = window.scrollY || window.pageYOffset || 0;
        if (Math.abs(y - lastReported) < 8) return;
        lastReported = y;
        try {
            window.webkit?.messageHandlers?.scroll?.postMessage({ y: y });
        } catch (e) {}
    }

    // rAF-throttle during active scrolling so the native side hears about every
    // movement (toolbar can hide immediately). A trailing setTimeout captures the
    // final position once the user lets go, so the 1.2s idle-reveal arms from the
    // ACTUAL stop, not from somewhere mid-fling.
    window.addEventListener('scroll', function() {
        if (!rafScheduled) {
            rafScheduled = true;
            requestAnimationFrame(function() {
                emit();
                rafScheduled = false;
            });
        }
        if (endTimer) clearTimeout(endTimer);
        endTimer = setTimeout(emit, 120);
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
