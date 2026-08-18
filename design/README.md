# Handoff: OCRadar UI restyle (OCRadarKit/Sources/OCRUI)

## Overview

A full visual restyle of the OCRadar iOS app — an on-device **awareness tool**
that compares a photo of the mouth with reference images and shows which
categories look similar. Four tabs (Home, Scan, History, Settings) plus three
sheets (Result, Scan detail, Medical disclaimer). **Restyle only:** every screen,
public API, demo-mode honesty surface and accessibility affordance in the current
package is preserved.

Target: `OCRadarKit/Sources/OCRUI/` on branch `ankthba/app-rework`
(repo `OCRadar/OCR-iOS`).

> **The vocabulary is not a style choice.**
> This document opened with "an on-device oral-lesion screening aid" until the
> claim-language pass, which is the exact framing `LICENSE` forbids and the first
> word on `docs/APP_STORE.md`'s never-use list. The app does not screen, detect,
> diagnose, assess, evaluate, or rule anything in or out; it reports *visual
> similarity* to reference categories and never states what a lesion is. This is
> the design spec of record for a publicly visible repository, so a sentence here
> is quotable against the product — and it is what the next implementer builds
> to. Every screen description below is written in that vocabulary, and a change
> that reintroduces "screening", "detect", "confidence", "risk tier" or a
> condition name presented as a finding is a regression in this document before
> it is one in the code. `MedicalDisclaimer` and `RiskLevel.displayLabel` carry
> the canonical wording.

## About the design files

`OCRadarScreen.dc.html` in this bundle is a **design reference built in HTML** — a
prototype showing intended look, layout and behaviour. It is not production code
and should not be ported literally. The task is to **recreate it in SwiftUI**
inside the existing `OCRUI` package, using its established patterns
(`Theme`, `OCRCard`, `OCRClassBar`, `OCRMetaLine`, `OCRMedicalNotice`, the
`@Entry var lesionClassifier` environment key, SwiftData `@Query`).

`GlassCard`, `ScoreRow` and `RiskBadge` were named here and no longer exist.
`RiskBadge` in particular was the tier-coloured badge, and its removal is
load-bearing: tiers now carry **no colour of their own**, which is what lets the
medical notice be the one red object in the app without a reader mistaking red
for "this result is bad" (see `OCRMedicalNotice`). Do not reintroduce it.

Open the HTML in a browser to interact with it. It is a single Design Component:
the markup is inside `<x-dc>`, the state machine is the `class Component` script at
the bottom of the file.

## Fidelity

**High-fidelity.** Colours, gradients, type sizes, letter-spacing, radii, spacing
and contrast ratios are final and measured. Recreate pixel-faithfully. Every value
below was verified in the running prototype.

Two deliberate substitutions in the prototype, to translate on the way in:
- Icons are Material Symbols Rounded (web font). **Use SF Symbols** — mapping table below.
- Camera preview, captured photo and the comparing spinner are placeholders. Wire to the real `CameraService` / `AVCaptureVideoPreviewLayer`.

---

## Design tokens

### Colour

| Token | Hex | Use |
| --- | --- | --- |
| canvas | `#000000` | app background, every screen |
| surface | `#131316` | cards, list groups |
| surfaceRaised | `#26262C` | secondary buttons, avatar chips, progress track, selected tab pill |
| tabBarFill | `#16161A` | floating tab bar |
| divider | `#1E1E24` | 1px separators inside cards |
| textPrimary | `#FFFFFF` | titles, values |
| textSecondary | `#8E8E93` | body copy, labels, meta |
| textTertiary | `#76767E` | footnotes, disclaimer |
| numeralMuted | `#E8E6EC` | large numerals on non-highlighted rows |
| chevron | `#5A5A62` | disclosure chevrons |
| accent | `#C77BE8` | links, icons in list rows, reticle, chart line |
| accentHover | `#DBA5F0` | link pressed |
| salmon | `#E39B7B` | demo dot, newest chart point. **Data only — never behind text** |
| mint | `#5FD3A6` | live-model dot (non-demo state only) |
| stageFill | `#0C0C0F` | camera stage |
| stageBorder | `#1C1C22` | camera stage border |
| radarRing | `#26262E` | radar rings + crosshair |

### Gradients

Derived from the app's own `ocrnew` logo asset (deep indigo → purple → salmon).

| Token | Value | Use |
| --- | --- | --- |
| heroGradient | `152°, #4B2E8F 0%, #8B4E9E 52%, #96554F 100%` | Home hero panel, Result & detail sheet headers |
| bandGradient | `152°, #4B2E8F 0%, #8B4E9E 62%, #96554F 100%` | Scan / History / Settings header bands, disclaimer sheet header |
| buttonGradient | `152°, #7C3FBF → #96554F` | filled buttons, shutter, History avatar for newest scan |
| barTop | `90°, #B96FDA → #C98A72` | Result sheet top-class bar only |

**Do not lighten the third stop.** It was `#D08A6E`; white text over it measured
2.8–3.7:1. At `#96554F` every label on the gradient measures **≥5.08:1**
(verified: 5.14 / 5.15 / 5.75 / 6.92). White on `buttonGradient` measures ≥5.6:1.

Bar fills below the top class, descending: `#8B4E9E`, `#6B3E86`, `#553171`, `#4B2E8F`.

### Typography — SF Pro (system), all weights semibold(600) or medium(500)

| Role | Size | Weight | Tracking | Notes |
| --- | --- | --- | --- | --- |
| Hero numeral | 76 | 600 | −3.6 | `monospacedDigit()`, line-height 0.95 |
| Screen title / result class | 26 | 600 | −0.7 | |
| Section head | 21 | 600 | −0.45 | "Earlier scans" |
| Card title / wordmark | 16.5 | 600 | −0.25 | |
| Row title | 16 | 500 | −0.2 | |
| List value / class name | 15.5–16 | 400–500 | — | |
| Body | 14.5 | 400 | — | line-height 1.5 |
| Header subtitle / row meta | 13.5 | 500/400 | — | on gradient: white at 92% opacity |
| Section label | 13 | 600 | — | `textSecondary`, above card groups |
| Footnote | 13 | 400 | — | `textTertiary`, line-height 1.6 |
| Chart axis | 11.5–12.5 | 400 | — | |
| Rail numeral | 26 | 600 | −1.0 | `monospacedDigit()` |

Every numeral uses `.monospacedDigit()`. Dynamic Type must scale all of the above —
use `.font(.system(size:weight:))` with `@ScaledMetric`, or map to text styles.

### Radii, spacing, geometry

- Hero panel: bottom corners **34**. Header bands: bottom corners **30**. Sheets: top corners **30**.
- Cards **16** (rail rows) / **18** (list groups) / **20** (chart, callout, Result cards).
- Capsules **100** — buttons, tab bar, avatars, badges.
- Camera stage **24**, inset 16 from screen edges.
- Page margin **26**. Section gap **24–34**. Card padding **16–22**.
- List row height **54**. Divider inset: 53 when the row has a leading icon, 18 otherwise.
- Tab bar: floating, inset 14 left/right, **30** from bottom, height **62**, inner pill height **50**.
- Header band height 150 (Scan); Home hero pads 96 top / 30 bottom.
- Minimum hit target 44×44 everywhere.

### SF Symbol mapping

| Prototype (Material) | SF Symbol |
| --- | --- |
| `photo_camera` | `camera.fill` |
| `center_focus_weak` | `camera.viewfinder` |
| `home` | `house.fill` |
| `stacks` | `clock.arrow.circlepath` |
| `settings` | `gearshape.fill` |
| `chevron_right` | `chevron.right` |
| `memory` | `cpu` |
| `numbers` | `number` |
| `lock` | `lock.shield` |
| `mail` | `envelope` |
| `description` | `doc.text` |
| `medical_services` | `stethoscope` |
| `bolt` | `bolt.fill` |
| `photo_library` | `photo.on.rectangle` |

---

## Screens

### 1. Home (`HomeView.swift`)

Scrolls under the hero; no nav bar, no large title.

**Hero panel** — full-bleed `heroGradient`, bottom corners 34, padding 96/26/30/26.
Two decorative concentric circle outlines (`rgba(255,255,255,.14)`, 1px) bleeding
off the top-right — they echo the logo's radar rings. Contents top to bottom:
1. Row: `ocrnew` logo 26×26 circle + "OCRadar" (16.5/600). Trailing: 34×34 circular button, fill `white 16%`, `gearshape.fill` → Settings tab.
2. **Tappable block** (whole thing is one button → opens that record's detail sheet):
   - "Last scan · 1 hour ago" 13.5/500, white 92%
   - "91%" **76/600/−3.6**, monospaced
   - "Looks most similar to" 13.5/500, white 92% — **not optional.** Without it the block reads "91% — <category>", which is a named condition with a score attached: a diagnosis, in the app's largest type, on the first screen anyone opens.
   - "Common tissue appearance" 26/600/−0.7 — the *reference category* the photo resembled, never a finding. `ModelManifest.ClassInfo.displayName` states the rule at the source.
   - "Routine · demo result" 15.5, white 92% — the tier is `RiskLevel.displayLabel`, i.e. next-step guidance ("Routine" / "Worth asking about" / "See a professional soon"), never "Low/Moderate/High risk". The "· demo result" suffix appears only in demo mode.
3. Primary button: full width, height 54, capsule, **solid white** fill, label `#2A1745`, `camera.fill` + "New scan" 16.5/600 → Scan tab.

**Body** (black, 26pt margins, 34 top):
- "Earlier scans" 21/600/−0.45 over "Closest reference category and how similar it looked" 13.5 secondary, + "See all" 15 accent (→ History). The second line is what names the two columns in the rows below; without it Home has nothing anywhere qualifying a numeral parked beside a category name.
- Two rows, gap 10, each a button (`surface`, radius 16, padding 16/18): the similarity percentage 26/600 **with its percent sign** in a 52pt column, then title 16/500 + meta 13.5 secondary, then chevron. Rows 2 and 3 only — the newest record is the hero.
- Chart card (`surface`, radius 20, padding 22/20): "Similarity over time" 16.5/600, "Closest-match similarity across all N scans" 13.5 secondary — plus "· demo placeholders" when every plotted record is a demo result — then an area chart. Not "Confidence over time": confidence is certainty in a conclusion, and a rising line under that word reads as a condition getting worse.
- Model-status card — **branch on `classifier.kind`** (see Honesty rules).
- Footnote: `MedicalDisclaimer.short` in an `OCRMedicalNotice` + a single "Read the full notice" link → disclaimer sheet. One route to that sheet, not two.

**Chart** (viewBox 310×120): area fill `#C77BE8` at 38%→0% vertical; line `#C77BE8` 2.25pt; points at x = 34 / 155 / 276; y = `104 − p × 78`; newest point a 4.5pt circle, `#000` fill with `#E39B7B` 2.25pt stroke. Axis labels 11.5 at the same three x values — **anchor labels to the data x-coordinates**, not a distributed row (an earlier version used space-between and sat up to 33px off).

### 2. Scan (`ScanView.swift`)

- `bandGradient` header, 150 tall, bottom corners 30, one decorative ring top-right. Bottom-left: "Scan" 26/600 + "Nothing leaves your iPhone" 13.5 white-92%. Bottom-right: "Step 1 of 2" / "Step 2 of 2" 13.
- **Camera stage**: inset 16, top 166, bottom 104, radius 24, fill `stageFill`, 1px `stageBorder`. Diagonal 115° hairline stripe texture at 4.5% white stands in for the preview — replace with the live preview layer.
- **Radar + reticle, concentric.** Radar: 250×250 SVG, rings r = 118/80/42, crosshair lines, one `#C77BE8` sweep arm rotating 360° over 4s linear, opacity 55%, centred at y 206 in stage coordinates. Reticle: four 26pt corner brackets, 2pt `#C77BE8`, outer radius 8, inset 40 left/right, top 113, height 186 — **its centre is 206, the same as the radar's.** Keep them in one coordinate space.
- Caption below: "Frame the area that concerns you / Hold steady in good light" 14, secondary, centred.
- Top-left status pill: `white 8%` capsule, 30 tall, salmon dot pulsing 2s + "Camera ready" 12.5/500. Top-right: 34pt circular flash toggle.
- Bottom controls, gap 40, centred: 48pt library button (`photo.on.rectangle`), **78pt shutter** — `rgba(199,123,232,.12)` fill, 2pt `rgba(199,123,232,.55)` ring, 60pt inner circle in `buttonGradient`; a 48pt spacer keeps the shutter optically centred.
- Capture-time line, before the shutter: `MedicalDisclaimer.capture`, verbatim.
- **Review stage**: stage shows the captured image; "Review" pill top-left; bottom actions "Retake" (`surfaceRaised`, flex 1) + **"Compare"** (`buttonGradient`, flex 1.4), height 52, capsules. The prototype said "Analyze"; the button that produces the result is the button that promises what the result will be, and the sheet it opens is headed "Visual comparison".
- **Comparing**: replaces the actions with a capsule, `rgba(199,123,232,.16)`, pulsing dot + "Comparing on device…" 16/600. Prototype waits 1200ms then presents the Result sheet; in the app this is the real `classify` call.

### 3. History (`HistoryView.swift`)

- `bandGradient` header: "History" 26/600 + "Past comparisons — closest reference category and how similar it looked. Saved on this device only." 13.5; trailing count "3 scans" / "No scans" 13. The subtitle is the one place this list states its frame *and* names what the avatar numeral measures, which is why no row repeats it and why no notice is wedged between rows.
- One group label "August 2026" 13/600 secondary, then three rows in a 10pt gap stack, each a button (`surface`, radius 16, padding 16/18): 52pt circular avatar with the similarity percentage **including its percent sign** (17/600) — newest uses `buttonGradient`, older use `surfaceRaised` — then title 16/500, meta 13.5 secondary, chevron.
- Meta format: `"<Tier> · Demo · 1h"`, where `<Tier>` is `RiskLevel.displayLabel` ("Worth asking about"), **never** "<Tier> risk". **Keep the short date tokens** (`1h`/`1d`/`5d`); longer forms wrap the 226pt column and make rows uneven (measured 84/84/84 with short tokens).
- Group by real month — the three seeded scans all fall inside five days, so there is exactly one group.
- Footnote: "Deleting a scan removes it permanently." Keep swipe-to-delete.
- **Empty state** (restyled, not `ContentUnavailableView`): centred, 80 top pad — 66pt radar glyph with a dashed middle ring and a `#4A4A52` centre dot, "No scans yet" 21/600, "Photos you compare in the Scan tab are saved here, on this device only." 14.5 secondary, then a `buttonGradient` capsule "Take your first scan".

### 4. Settings (`SettingsView.swift`)

`bandGradient` header ("Settings" + "Model, privacy and support"). Then four
groups, each a 13/600 secondary label above an 18-radius `surface` card. **No
system grouped-list styling.**

1. **Model** — rows "Engine" (`Demo` / `Core ML`) and "Version" (`mock-0.0.0` / the model version), 54 tall, leading accent icon, trailing value. Values branch on classifier (see Honesty rules). A caption under the card says what the model does — "compares your photo with reference images and reports which categories look similar. It does not identify conditions" — because two rows naming an engine describe software without saying what it is for, and a reader fills that in with "detects".
2. **Reference categories & next steps** — a padded card listing all five manifest classes, 13pt gaps, name 15.5 `numeralMuted` left, next-step tier 14 secondary right (wrapping, never clipped). Drive from `classifier.manifest.classes`; do not hardcode. In demo mode a caption marks the taxonomy as the stand-in's. Not "Classes & risk tiers": that names the columns as a taxonomy of conditions and a severity for each, which is the claim the app does not make.
3. **Privacy** — icon + "On-device only" 16/600 + the privacy paragraph 14 ("All processing happens on this device", not "All analysis").
4. **Support** — "Contact support" (mailto) and "Medical disclaimer" (→ sheet). **About** — "App version", "Copyright".

Footnote: `MedicalDisclaimer.short`.

### 5. Result sheet (`ResultView.swift`)

Presented after a successful `classify`. Top inset 48, top corners 30.

- **Gradient header** (`heroGradient`, bottom corners 34): "Visual comparison" 15/600 left, "Done" button right (capsule, `white 20%`, 34 tall). Then "Compared just now · demo result" 13.5 white-92%, "52%" 76/600/−3.6, **"visual similarity" 26/600** directly beneath the numeral so the two read as one phrase, then "Closest match: Leukoplakia" and the next-step tier on the line below, 15.5 white-92%.

  **This ordering is the whole point of the screen.** The header used to read `"52%"` → `"Leukoplakia"` → `"Moderate risk"`: a named condition, a confidence, and a severity, stacked in descending size. That is the shape of a diagnosis, and no fine print underneath changes how it is read. The largest words on the sheet must assert only how alike two images looked; the category name is a supporting detail, and it never appears in this header without the "Closest match:" prefix.
- **Medical lead**, directly under the header and above everything else: `MedicalDisclaimer.resultLead` in the red bordered `OCRResultDisclaimerLead`, with "Read the full notice" inside it opening `MedicalDisclaimerSheet`. This is the sheet's **one** warning object. The full five-paragraph `MedicalDisclaimer.full` is *not* rendered inline here — it was, on top of this lead, and two red panels around one result halve the warning rather than doubling it.
- **Demo banner** (demo only): 16-radius outlined card (1px `#2A2A2E`), salmon dot, **"Demo result — no trained model installed."** bold + the message naming the mechanism: the score comes from the photo's dimensions, not from what is in it, so every photo of the same size returns the same numbers. Set at body size in `textPrimary`, not at meta size in grey — in a build with no bundled model this is the most load-bearing sentence on the sheet. Keep the full title; do not shorten.
- **Similarity ranking** card (radius 20), titled "Similarity ranking" over "How closely this photo resembled each reference category": one row per class — name 15 + percent 14.5 secondary monospaced, then a 6pt capsule bar, track `surfaceRaised`. Top class uses `barTop`; the rest step down the purple ramp. Drive from `result.scores`. Not "All classes": a column of category names each carrying a percentage under an unqualified title is a differential diagnosis.
- **Professional-care callout**, last on the sheet — see Honesty rules. Radius 20 `surface`, `stethoscope` accent icon + title 16.5/600 + body 14 secondary.

### 6. Scan detail sheet (`HistoryDetailView`)

Same gradient-header structure and the same slot mapping the Result sheet uses,
driven by the tapped `ScanRecord`: eyebrow "Saved comparison", timestamp 13.5,
similarity 76/600, the words "visual similarity" 26/600, then "Closest match:
<category>" and the next-step tier 15.5. Then `OCRResultDisclaimerLead`, then the
demo notice (demo only, `HistoryDetailView`'s own wording: "This scan was made
without a trained model…"), then an 18-radius card of four 54pt rows — **Visual
similarity, Next step, Model, Scanned** — then the saved photo.

The two result surfaces are framed identically and carry the same one warning
object in the same position. Rows named "Confidence" and "Risk tier" are what
this sheet does not have: the number is how alike two images looked, and the
value under "Next step" is an action, not a severity.

**No class breakdown here** — that belongs only to a fresh comparison, matching
the existing split between `ResultView` and `HistoryDetailView`.

### 7. Disclaimer sheet (`RootView.swift` `DisclaimerSheet`)

Bottom sheet 582 tall, top corners 30. `bandGradient` header with a 44×5 grab
handle at 40% white, the `ocrnew` logo at 46pt, and "Before you begin" 26/600
(matches the existing navigation title). Body: `MedicalDisclaimer.full` 15/1.6 in
`#A8A8AE`, scrollable. Footer: full-width `buttonGradient` capsule "I understand"
→ sets `hasAcknowledgedDisclaimer`. Keep `.interactiveDismissDisabled()`.

---

## Honesty rules — do not simplify these

These mirror logic already in the package. Every one of them was got wrong at
least once while building the prototype; they are the highest-risk part of this
restyle.

1. **Model status** — `classifier.kind == .mock` → "Demo mode — no trained model installed" + stand-in copy + salmon dot. Otherwise → "Model \(manifest.modelVersion)" + "On-device Core ML model installed and ready." + mint dot. Home, Settings (Engine `Demo`/`Core ML`, Version `mock-0.0.0`/version), History meta (`· Demo` token) and the detail sheet Model row **all** read from this. A build where one surface says demo and another says a real model is installed is a defect.
2. **Professional-care callout has two mutually exclusive branches** (`ResultView.professionalCallout`): `top.riskLevel >= .moderate && !result.isDemoResult` → "What to do next" / `RiskLevel.guidanceDetail` for that tier ("Worth bringing to a dentist or doctor the next time you see one." / "Book a visit with a dentist or doctor in the next few days."). Otherwise → "When in doubt, see a dentist or physician" / "This app cannot tell you what something is. If anything in your mouth concerns you, have it looked at." **A demo score never gets the tier copy.** Never blend the two strings, and never hand-write either at the call site.

   The earlier copy — "This result falls in a tier that warrants professional evaluation" and "Only a professional exam can rule a lesion in or out" — is **retired and must not come back**. The first is a severity claim about the reader dressed as a routing instruction; the second is the vocabulary of screening, which this app does not do.
3. **Per-class `summary` is withheld for demo results** — pairing real medical guidance with a fabricated score lends it unearned weight. (The prototype omits summaries entirely; if you add them, keep the suppression.)
4. **Disclaimer copy comes from `MedicalDisclaimer` only** — `.short` for the Home/Settings banners, `.capture` before the shutter, `.resultLead` on both result surfaces, `.full` for the first-launch gate and the disclaimer sheet those surfaces open. Never paraphrase; that type exists so the wording stays identical everywhere. **Restraint is part of the rule:** one lead plus one route to the full text per results surface. A screen that stacks more of them is not being more careful, it is being ignored more thoroughly.
5. **Class taxonomy comes from `ModelManifest`** — five classes: Common tissue appearance (low), Aphthous ulcer (canker sore) (low), Oral lichen planus (moderate), Leukoplakia (moderate), Erythroplakia (high). Every `displayName` names a *reference category*, never a finding about the reader: the first one was "No visible lesion", which is a rule-out the app has no basis to state. The app does **not** claim to detect carcinoma; never add such a class.
6. **A record's detail must match the record tapped.** Each row carries its own reference category, similarity score, next-step tier and timestamp.

---

## State

```
selectedTab: .home | .scan | .history | .settings
scanStage:   .live | .review | .comparing         // Scan tab
sheet:       none | result | detail | disclaimer
detailRecord: ScanRecord?                        // which record the sheet shows
hasAcknowledgedDisclaimer: Bool                  // @AppStorage, existing
```

Camera fallbacks stay driven by `camera.state` (`.denied` / `.unavailable` /
`.failed`). In the prototype these are a `scanState` prop so each can be
inspected; `historyEmpty` and `demo` are props for the same reason.

Transitions: shutter → `.review`; Compare → `.comparing` → `classify` → Result
sheet + `modelContext.insert` + immediate `save()`; Retake → `.live`; row tap →
detail sheet; Done → dismiss. Sheets rise 30pt over 0.42s,
`cubic-bezier(.32,.72,0,1)` — closest SwiftUI equivalent
`.timingCurve(0.32, 0.72, 0, 1, duration: 0.42)`. Radar sweep: 4s linear, repeat
forever. Status/comparing dots: opacity 0.3→1, 1–2s ease-in-out, autoreverse.

---

## Accessibility — must survive

- Every tappable surface is a real button, including all three scan records and the Home hero. An earlier draft left two rail cards as plain divs and the hero unreachable.
- Icon-only buttons carry labels: "Capture photo", "Choose a photo from your library", "Toggle flash", "Settings".
- Record buttons carry a full sentence, framed the way the visual row is framed: "Scan from yesterday: looks most similar to leukoplakia, 64 percent visual similarity, worth asking about." Never "64 percent confidence, moderate risk" — read aloud with nothing around it, that is the most diagnosis-shaped sentence the app could produce.
- Tabs expose selection (`aria-current` in the prototype → `.accessibilityAddTraits(.isSelected)`).
- The chart is `role="img"` with its values enumerated: "Closest-match visual similarity: 55 percent five days ago, 64 percent yesterday, 91 percent one hour ago." In SwiftUI: `.accessibilityElement()` + `.accessibilityLabel(...)`. Decorative rings and glyphs are hidden.
- Contrast: all body text ≥4.5:1. Text on gradient is white at 92% minimum and measures ≥5.08:1 at the lightest point. `#8E8E93` on black = 6.44:1; `#76767E` = 4.6:1. Do not use anything lighter than `#76767E` for text on black.
- Dynamic Type: the similarity ring in the old build used `@ScaledMetric` so the interior text stayed inside the stroke — keep that pattern for any circular gauge, and let the 76pt numerals shrink/wrap rather than clip.

## Dark mode

The app is dark-only — that is the brand. Apply
`.preferredColorScheme(.dark)` at `RootView`. There is no light variant.

## Public API

`RootView(classifier:)` is unchanged. The `ocrnew` asset lives in the **app
target**, not the package, so pass it in as an optional `Image` (or keep the
package asset-free and inject it) rather than adding assets to `OCRadarKit`.

## Assets

| File | Source |
| --- | --- |
| `assets/ocrnew.png` | `OCRadar/Assets.xcassets/ocrnew.imageset/OCRadarNewCircle.png` — the app mark, a concentric radar "C". The gradient palette in this spec is sampled from it. |
| `assets/ocr-circle.png` | `OCRadar/Assets.xcassets/OCR-Circle.imageset/OCR-Circle.png` — alternate mark, unused in this design. |

## Files in this bundle

| File | What it is |
| --- | --- |
| `OCRadarScreen.dc.html` | The design. Open in a browser; interactive. |
| `OCRadarScreen v1.dc.html` | Earlier direction, superseded. Reference only. |
| `HomeA.dc.html`, `HomeB.dc.html` | Two rejected Home directions (editorial, instrument). Context for why the final one was chosen. |
| `ios-frame.jsx`, `support.js` | Runtime for the HTML prototype. Not part of the design. |
| `assets/` | The logo assets above. |
| `github.md` | Repo association and the screen → source-file map. |

## Verification

The prototype was checked by driving it: tab switching, capture → review →
compare → Result, every record opening its own detail sheet, all four camera and
empty states, the demo flag flipped both ways across all four surfaces, History
row heights measured even at 84pt, chart labels measured on their data points,
and contrast computed per label. Reproduce that pass on device with the existing
`-qaTab` / `-qaSeedHistory` / `-qaShowResult` launch arguments.
