(function() {
    var lastId = null;
    var debounce = null;

    function findCurrent() {
        // Threshold sits a third of the way down the viewport — same place a reader's
        // eye lives most of the time. Find the LAST heading whose top is above it.
        var threshold = window.scrollY + window.innerHeight * 0.30;
        var headings = document.querySelectorAll('h2[id], h3[id]');
        var current = null;
        for (var i = 0; i < headings.length; i++) {
            var h = headings[i];
            if (h.offsetTop <= threshold) {
                current = h;
            } else {
                break;
            }
        }
        return current ? current.id : null;
    }

    function check() {
        var id = findCurrent();
        if (id === lastId) return;
        lastId = id;
        try {
            window.webkit?.messageHandlers?.activeSection?.postMessage({ id: id || '' });
        } catch (e) {}
    }

    window.addEventListener('scroll', function() {
        if (debounce) clearTimeout(debounce);
        debounce = setTimeout(check, 120);
    }, { passive: true });

    // First emit after layout settles
    setTimeout(check, 400);
})();
