# Reader loading

Measured on the iPhone 16 Pro simulator, Debug build, opening a cached
article. A device build is faster, but the shape holds.

## Where the time went

| stage | before | after |
|---|---|---|
| WebView construction | 23 ms | 23 ms |
| HTML in hand (SwiftData) | 141 ms | 141 ms |
| `didCommit`, document accepted | 415 ms | 415 ms |
| `didFinish`, whole document + subresources | 1012 ms | 1027 ms |
| **reader revealed** | **1012 ms** | **751 ms** |

Two things this ruled out. Network is not the cost: a cached open costs the
same as a cold one, so prefetching harder would not help. Webfonts are not
the cost either: `FontURLSchemeHandler` never fires, because EB Garamond
resolves from the natively registered `UIAppFonts`.

## What changed

The reader revealed on `didFinish`, which waits for the entire document and
every subresource, including body images far below the fold. It now reveals
on a `painted` message posted from `painted.js` after two animation frames,
with `didFinish` kept as a fallback so a script failure cannot strand the
reader on the preview. That is 276 ms earlier.

The preview also stopped announcing itself. The "Loading article…" row now
appears only after 1200 ms, so a normal open never flashes it, and the bold
lead phrase is taken from the summary's own `extract_html` rather than
guessed by matching the title. The guess missed every article whose lead
differs from its name, so "Dolly Rebecca Parton Dean" rendered plain in the
preview and bold in the article, restyling on swap.

## Next: share one WebView configuration

The remaining 336 ms between `didCommit` and first paint is WebKit parsing,
styling and laying out a large document. The scripts are not to blame; all
eight total 304 lines.

The lever is that every article builds a fresh `WKWebViewConfiguration` with
its own `.nonPersistent()` data store. That prevents WebKit reusing a warm
content process, re-parses the same CSS on every open, and means the hero
image is re-fetched per article even though `ImageLoader` already holds it,
because the WebView cache is discarded with the store.

Sharing one configuration, process pool and ephemeral data store across
articles should cut the commit latency and the hero refetch. The privacy
posture is unchanged: the store stays ephemeral and is still discarded when
the app exits. The care needed is around the crash-recovery remount, which
deliberately rebuilds the WebView when the content process is reaped.

Deferred because 751 ms with no visible flicker may already be good enough.
Measure again on device before deciding.
