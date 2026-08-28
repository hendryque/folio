# Typography record

A record of what the reader's type settings were, what an intermediate pass
changed them to, and where they landed. Kept because several of these numbers
interlock, and changing one without the others is how the column goes wrong.

## The face, measured

All numbers below rest on EB Garamond's actual metrics, measured from the
bundled OTFs with CoreText rather than estimated:

- x-height 0.400 em. At 17px that is 6.80px. Georgia sits near 0.48, SF near
  0.53, so 17px EB Garamond reads optically like about 13px of a screen sans.
- Real ink, measured on glyph paths rather than the font's declared ascent:
  13.52px above the baseline, 4.93px below, at 17px.
- Average character width 0.391 em in English running text, 0.407 em in
  German. Lowercase alphabet length 193px at 17px.

Two consequences. The face is small on the body, so it tolerates tighter
leading than its nominal size suggests. Its extenders are long, so the
interlinear channel closes faster than the line-height number implies.

## Reading situation

A Wikipedia article in a reader is differentiated reading, not linear reading:
the lead is read through, then the eye jumps by section, consults the infobox,
follows a link out. That licenses slightly tighter leading and a slightly
shorter measure than a novel wants, and it raises the value of an even,
unspotted column.

## The three states

| | before-before | before | after |
|---|---|---|---|
| body line-height | 1.62 | 1.47 | **1.52** |
| interlinear channel | 9.10px, 1.34 x-heights | 6.54px, 0.96 x-heights | **7.39px, 1.09 x-heights** |
| measure cap | none | 31rem, 79 chars | **26rem, 66 chars** |
| paragraph gap | 0.85em, 0.52 line | 0.85em, 0.58 line | **0.76em, exactly 0.50 line** |
| link weight | 600 | inherit | inherit |
| display title | 2.6em, scales to 1.6x | 44.2px, capped 1.2x | capped 1.2x |
| Today tile title | Italic 22 | Medium 22 | **MediumItalic 22** |
| Nearby card title | Regular 16 | Medium 16 | Medium 16 |
| `lang` on root | absent | restored | restored |

Bold marks what this pass changed. Unbolded values in the "after" column were
already right and were left alone.

## Why each number

**Leading, 1.62 to 1.47 to 1.52.** The measure is 50.4 characters on an
iPhone 13 mini and 54.4 on a Pro. That is short, and short measures need less
leading, because the return sweep is short and doubling a line is unlikely. So
1.62 was genuinely over-leaded: the lines drifted apart and the paragraph lost
its even gray. The correction was right in direction. But 1.47 puts the white
channel at 0.96 x-heights, the tight edge, and EB Garamond's long extenders
close that channel faster than most faces. The working rule, carried from
memory rather than a citable page, is that the channel wants to sit at or just
above one x-height. 1.52 gives 1.09. Craft principle.

**Measure cap, 31rem to 26rem.** 31rem is 527px, which is 79 characters, past
the comfortable ceiling that both Bringhurst and the German tradition put
around 70 to 75. It also never fired on a phone, where the column is 335 to
362px, so on the device this app is actually read on it changed nothing. 26rem
is 442px, 66 characters, the classic single-column target. Expressing the cap
in rem rather than px is correct and was kept: the cap then holds character
count constant as the reader pinches, instead of holding pixels constant.
Convention, with physiology underneath.

**Paragraph gap, 0.85em to 0.76em.** 0.76em is 12.92px, exactly half of the
25.84px line. This is the least consequential change of the four and it should
be described honestly: on a single scrolling column with no facing pages and
no cross-column register, the strict baseline-grid argument is weak. What the
gap must do is read as clearly larger than the line gap, and 0.85em already
did that. The change buys tidiness, an exact fraction of the line rather than
an arbitrary one, not a fix for a visible fault. Taste.

**Links, 600 to inherit.** Kept from the intermediate pass, and the best of
its changes. A Wikipedia paragraph carries a dozen links; setting each in 600
produces a page spotted with arbitrary dark anchors and the gray value
collapses. Colour alone carries the signal, as it did in V for Wikipedia. Note
this is now single-channel differentiation, so contrast in the sepia and dark
themes is doing real work and should not be weakened.

**Display title cap.** Kept. Body text may grow to 1.6x while the title stops
at 1.2x, so the display-to-text ratio compresses from 2.6 to 1.95 as the
reader enlarges type. Correct: someone enlarging body text wants reading
comfort, not a bigger poster. It also stops long titles overflowing the fixed
4:3 hero.

**Today tile, Italic to Medium to MediumItalic.** Italic Garamond at 22px over
a photograph under a 42 percent tint is fragile: an old-style italic's
hairlines thin to nothing and break up against image noise. Moving to Medium
fixed that but cost the app its voice, since the italic echoes the icon's
italic F and the reader's italic hero. EB Garamond Medium Italic, Georg
Duffner's own cut, resolves the trade: same x-height (0.407) and cap height
(0.650) as Medium roman, so nothing shifts, with the italic restored.

**Nearby card, left as Medium roman.** Deliberately not made italic. That row
was Regular roman before this sequence started, so italic there would be
inventing a voice rather than restoring one. Medium still earns its place: the
card sits on translucent material, where Regular goes weak.

## Today grid

Today is a scanning surface, so the rules differ from the reader: word shape
and legibility over a photograph matter more than an even gray.

- Tile titles are EB Garamond Medium Italic 22. Medium because an old-style
  italic's hairlines break up over image noise at this size; italic because
  it is the app's voice, echoing the icon and the reader hero.
- Descriptions were letterspaced all-caps in SF at 10px. All-caps destroys
  the word shape, which is the only cue that works at scanning speed, and
  German descriptions ran to three tracked lines and still truncated. They
  are now Garamond Medium 13, sentence case, no tracking, two lines. One
  weight in two styles; size alone carries the hierarchy.
- The flat 42% tint was replaced by a bottom-weighted scrim, because a
  constant cannot serve both a dark ink painting and a bright film poster.
  The scrim must be sized to the text, not the tile: a two-line title with a
  two-line description reaches 42% of tile height and a three-line title
  reaches 53%. The first attempt faded to alpha 0.23 by 42%, leaving titles
  at 1.5:1 contrast over a yellow poster. It now holds 0.72 at 32% and 0.40
  at 60%, clear at 88%, plus a 0.5 black text shadow.

## Hyphenation

Restoring `lang` on the document root gave iOS the right hyphenation
dictionary, which body text needs at this measure, German especially. It also
switched hyphenation on for display type, which produced "Metropolitan Muse-/
um of Art" in the hero. Headings and `.folio-title` are now `hyphens: none`.
Display type is set wide enough never to need it, and a hyphenated headline
reads as unattended typesetting.

## What is still open

The `lang` restoration means iOS now picks the right hyphenation dictionary
per article, which matters most for German compounds. Worth confirming on a
German article with a long compound in an infobox value column that the rag
improves. Typographizer is separately handed the article language for quote
marks, so German articles should show low-high quotes and English curly
doubles; that is existing behaviour, not changed here, but it is the other
half of locale correctness.

**Adaptive tile scrim.** The Today scrim is a fixed ramp, so it is a
compromise between the darkest photograph and the brightest poster Wikipedia
returns. Tuned for the poster, it visibly over-darkens the lower half of dark
portraits. The fix is to sample mean luminance of the bottom half of the
decoded image, which `ImageLoader` already holds, and modulate peak alpha
between roughly 0.45 and 0.90. Deferred until the darkening actually annoys
in daily use.

## App icon: open question on the rule

Measured on the shipped 1024px icon. The letter's foot, where it meets the
ground, runs x 206-498, centre 352. The rule runs 240-783, centre 511. So the
rule's centre sits 159px right of where the letter touches down, overhangs the
foot by 285px on the right, and does not overhang on the left at all: the foot
pokes 34px past the rule's left end.

The cause is that the rule was centred on the glyph's full inked bounding box,
and for an italic F that box is dominated by the top arm reaching right. The
bounding box is a poor proxy for where the letter's weight sits.

The icon and the header wordmark agree on rule width (86% of inked width
against the header's 92%) but disagree sharply on the gap: the header sits
1.8pt under a 14.3pt cap, a gap-to-cap ratio of 0.126, while the icon is 27px
under a 594px cap, ratio 0.045. The icon's gap is 2.8x tighter, from
overshooting an earlier correction.

Proposal, not yet applied: pull the rule back to the foot (172-532, centred on
352), then optically recentre the whole group roughly 40-60px right, and open
the gap to 45-55px. At 120px this reads as one mark rather than a letter with
a separate horizontal beneath it. The argument against is that a shorter rule
is a weaker horizontal at Settings size. Specimens are in
`~/Desktop/folio-icon-proofs` as `var-strip-120.png` and `var-A/B/C`.
