# Prompt for Claude Code

Paste this into Claude Code from the repo root (`OCR-iOS`), with this handoff
folder available.

---

Restyle the OCRadar UI in `OCRadarKit/Sources/OCRUI/` to match the design in
`design_handoff_ocradar_ui/`. Read `README.md` in that folder first — it is the
complete spec — then `OCRadarTheme.swift`, which contains the exact tokens and
starting SwiftUI primitives.

**This is a restyle.** Keep every screen, the public `RootView(classifier:)` API,
the SwiftData model, the camera flow, the QA launch-argument hooks
(`-qaTab`, `-qaSeedHistory`, `-qaShowResult`), all demo-mode honesty surfaces and
all accessibility affordances. Do not add features, do not change the class
taxonomy, do not rewrite copy that comes from `MedicalDisclaimer` or
`ModelManifest`.

Work in this order:

1. Replace `Components/Theme.swift` with the theme from the handoff. Add
   `OCRCard`, `OCRHeaderBand`, the three button styles, `OCRTabBar`, `OCRRadar`
   and `OCRReticle` as new files in `Components/`. `GlassCard` is superseded —
   the design is flat and opaque, not glassy; migrate its call sites to `OCRCard`.
   `RiskBadge` and `ScoreRow` are gone and stay gone: tiers carry no colour of
   their own, and the scores are drawn by `OCRClassBar`.
2. `RootView.swift`: add `.preferredColorScheme(.dark)`, hide the system tab bar
   and overlay `OCRTabBar`, and restyle `DisclaimerSheet` per README §7.
3. `HomeView.swift`: rebuild per README §1 — gradient hero with the tappable
   latest result, the earlier-scans rail, the confidence chart, the model-status
   card branching on `classifier.kind`, and the `MedicalDisclaimer.short` footnote.
   The chart's axis labels must be anchored to the data x-coordinates.
4. `ScanView.swift`: §2. Keep all three camera fallback layers but restyle them —
   no `ContentUnavailableView` styling. Radar and reticle must be concentric.
5. `HistoryView.swift`: §3, including the restyled empty state. Group rows by
   real month. Keep swipe-to-delete and the immediate `save()`.
6. `ResultView.swift`: §5. The header must read `<percentage>` → "visual
   similarity" → "Closest match: <category>" → the next-step tier, in that
   order — never a category name in the largest type with a percentage above it
   and a severity below. The professional-care callout keeps its two mutually
   exclusive branches, with the copy §5 and Honesty rule 2 now pin: a demo result
   must never get the tier branch, and the retired strings ("a tier that warrants
   professional evaluation", "rule a lesion in or out") must not come back.
7. `SettingsView.swift`: §4. Drive the class list from
   `classifier.manifest.classes`, not literals.

Then verify: build for the iPhone 17 Pro simulator
(`9E29E2AC-8E68-4423-A70A-18C90AF48010`), use the QA launch arguments to
screenshot every screen, and check §"Accessibility — must survive" — every
tappable surface a real button, icon buttons labelled, the chart carrying its
values as an accessibility label, all text ≥4.5:1, and layouts holding at larger
Dynamic Type sizes.

Read `README.md` §"Honesty rules" carefully before touching `ResultView` or any
model-status text. Each of those rules was got wrong at least once while the
design was being built, and they are the parts where a mistake is a medical
problem rather than a cosmetic one.
