#!/bin/bash

# Regenerates docs/screenshots/*.png. The app's DEBUG launch hooks land it in an
# exact state, so there is no UI-test navigation to keep working. Needs Python
# with Pillow, pngquant and oxipng. Usage: Tools/screenshots.sh ["iPhone 16"]
set -euo pipefail

SIM="${1:-iPhone 16}"
BUNDLE="me.scott.folio"
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
RAW="$(/usr/bin/mktemp -d)"
trap 'rm -rf "$RAW"' EXIT

echo "Building for ${SIM}…"
cd "$ROOT/Folio"
xcodebuild -project Folio.xcodeproj -scheme Folio -configuration Debug \
    -destination "platform=iOS Simulator,name=$SIM" build >/dev/null
# The destination matters here too: without it this resolves to the device
# build directory and the install fails with a device slice.
APP=$(xcodebuild -project Folio.xcodeproj -scheme Folio -configuration Debug \
    -destination "platform=iOS Simulator,name=$SIM" \
    -showBuildSettings 2>/dev/null | /usr/bin/awk '/ BUILT_PRODUCTS_DIR =/{print $3}' | /usr/bin/head -1)/Folio.app

xcrun simctl boot "$SIM" 2>/dev/null || true
xcrun simctl bootstatus "$SIM" -b >/dev/null 2>&1 || true
xcrun simctl install "$SIM" "$APP"
xcrun simctl ui "$SIM" appearance light >/dev/null 2>&1 || true

# Without this Nearby captures the permission prompt, not the map.
xcrun simctl privacy "$SIM" grant location "$BUNDLE" >/dev/null 2>&1 || true
xcrun simctl location "$SIM" set 40.7794,-73.9632 >/dev/null 2>&1 || true

grab() {
    local tag="$1"; shift
    xcrun simctl terminate "$SIM" "$BUNDLE" >/dev/null 2>&1 || true
    xcrun simctl launch "$SIM" "$BUNDLE" "$@" >/dev/null 2>&1
    local n=0
    while [ $n -lt 110 ]; do
        xcrun simctl io "$SIM" screenshot "$RAW/$tag.png" >/dev/null 2>&1 || true
        n=$((n + 1))
    done
    echo "  captured $tag"
}

# Always state the theme: the app persists the last one used, and it otherwise
# leaks into a shot meant to be light.
grab reader   -screenshotTheme light -screenshotArticle "Metropolitan Museum of Art" -screenshotLanguage en -screenshotScrollY 0
grab debug    -screenshotTheme debug -screenshotArticle "Bauhaus" -screenshotLanguage de -screenshotScrollY 0
grab today    -screenshotTheme light -screenshotTab today
grab nearby   -screenshotTheme light -screenshotTab nearby
grab settings -screenshotTheme light -screenshotSettings 1

RAW="$RAW" OUT="$ROOT/docs/screenshots" /usr/bin/env python3 - <<'PY'
from PIL import Image, ImageDraw, ImageFilter
import os, pathlib

RAW = pathlib.Path(os.environ["RAW"])
OUT = pathlib.Path(os.environ["OUT"])
OUT.mkdir(parents=True, exist_ok=True)

# The README's look, not a device bezel: status bar cropped, rounded card, soft
# shadow on transparency. Measured off the shipped files; change one number and
# the whole set needs retaking or it stops matching.
STATUS_BAR = 171
BASE_CARD = 440
BASE_MARGIN, BASE_RADIUS, BASE_BLUR, BASE_DROP = 26, 10, 12, 3
SHADOW_ALPHA = 18

def frame(src, card_w):
    k = card_w / BASE_CARD
    margin, radius = round(BASE_MARGIN * k), round(BASE_RADIUS * k)
    blur, drop = BASE_BLUR * k, round(BASE_DROP * k)

    body = src.crop((0, STATUS_BAR, src.width, src.height)).convert("RGBA")
    card_h = round(body.height * card_w / body.width)
    body = body.resize((card_w, card_h), Image.LANCZOS)
    mask = Image.new("L", (card_w, card_h), 0)
    ImageDraw.Draw(mask).rounded_rectangle([0, 0, card_w - 1, card_h - 1], radius=radius, fill=255)
    body.putalpha(mask)

    canvas = Image.new("RGBA", (card_w + margin * 2, card_h + margin * 2), (0, 0, 0, 0))
    silhouette = Image.new("L", canvas.size, 0)
    ImageDraw.Draw(silhouette).rounded_rectangle(
        [margin, margin + drop, margin + card_w - 1, margin + card_h - 1 + drop],
        radius=radius, fill=SHADOW_ALPHA)
    shadow = Image.new("RGBA", canvas.size, (0, 0, 0, 0))
    shadow.putalpha(silhouette.filter(ImageFilter.GaussianBlur(blur)))
    canvas.alpha_composite(shadow)
    canvas.alpha_composite(body, (margin, margin))
    return canvas

# Twice the README's display width, so the files stay sharp on retina.
for tag, width in [("reader", 758), ("debug", 758), ("today", 440), ("nearby", 440), ("settings", 440)]:
    frame(Image.open(RAW / f"{tag}.png"), width).save(OUT / f"{tag}.png", optimize=True)
    print(f"  framed {tag}")
PY

for tag in reader debug today nearby settings; do
    f="$ROOT/docs/screenshots/$tag.png"
    pngquant --quality=70-92 --speed 1 --force --output "$f" "$f"
    oxipng -o 4 --strip safe -q "$f"
    echo "  squeezed $tag ($(/usr/bin/stat -f%z "$f") bytes)"
done

echo "Done. docs/screenshots is regenerated."
