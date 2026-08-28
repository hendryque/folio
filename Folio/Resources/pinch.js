(function() {
    const MIN = 0.85, MAX = 1.6, TITLE_MAX = 1.2;
    const root = document.documentElement;

    function readScale() {
        const v = parseFloat(getComputedStyle(root).getPropertyValue('--folio-font-scale'));
        return Number.isFinite(v) && v > 0 ? v : 1.0;
    }
    function setScale(v) {
        const clamped = Math.max(MIN, Math.min(MAX, v));
        root.style.setProperty('--folio-font-scale', clamped.toFixed(3));
        root.style.setProperty('--folio-title-scale', Math.min(TITLE_MAX, clamped).toFixed(3));
        return clamped;
    }

    let pinching = false;
    let startDist = 0;
    let startScale = readScale();

    function distance(a, b) {
        const dx = a.clientX - b.clientX;
        const dy = a.clientY - b.clientY;
        return Math.hypot(dx, dy);
    }

    document.addEventListener('touchstart', function(e) {
        if (e.touches.length === 2) {
            pinching = true;
            startDist = distance(e.touches[0], e.touches[1]);
            startScale = readScale();
        }
    }, { passive: true });

    document.addEventListener('touchmove', function(e) {
        if (!pinching || e.touches.length !== 2 || startDist === 0) return;
        const dist = distance(e.touches[0], e.touches[1]);
        setScale(startScale * (dist / startDist));
        e.preventDefault();
    }, { passive: false });

    document.addEventListener('touchend', function(e) {
        if (!pinching) return;
        if (e.touches.length === 0) {
            pinching = false;
            const final = readScale();
            try { window.webkit?.messageHandlers?.fontScale?.postMessage({ scale: final }); } catch (err) {}
        }
    }, { passive: true });
})();
