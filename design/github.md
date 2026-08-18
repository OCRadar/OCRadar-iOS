repo: OCRadar/OCR-iOS
branch: ankthba/enhance-ui
path: OCRadarKit/Sources/OCRUI

Also read from the attached local working copy of the same repo
(folder "OCR-iOS", branch ankthba/app-rework per the brief).

## Last sync

date: 2026-08-17T03:47:00Z
commit: (unknown — read via attached local folder, no commit sha resolved)

### Updated in this project

- Redesigned the OCRadar UI as an interactive mockup: Home, Scan, History, Settings, plus the Result and disclaimer sheets.
- Direction reset twice on user feedback; final language is true black, flat opaque surfaces, one purple accent, data-forward Home.
- Adopted the bundled `ocrnew` mark (OCRadarNewCircle.png) as the app logo and derived the accent gradient from it.
- Demo-mode honesty surfaces preserved on Home, History rows and the Result sheet.

## Screen map

| Project screen | Built from repo files |
| --- | --- |
| Home | OCRadarKit/Sources/OCRUI/Screens/HomeView.swift, Components/Theme.swift, Components/OCRSurfaces.swift |
| Scan | OCRadarKit/Sources/OCRUI/Screens/ScanView.swift |
| History | OCRadarKit/Sources/OCRUI/Screens/HistoryView.swift, Components/OCRRowChrome.swift |
| Settings | OCRadarKit/Sources/OCRUI/Screens/SettingsView.swift |
| Result sheet | OCRadarKit/Sources/OCRUI/Screens/ResultView.swift, Components/OCRIndicators.swift (`OCRClassBar`), Components/OCRMedicalNotice.swift |
| Disclaimer sheet + tab shell | OCRadarKit/Sources/OCRUI/RootView.swift, Components/MedicalDisclaimerSheet.swift |

`GlassCard.swift`, `ScoreRow.swift` and `RiskBadge.swift` were listed here and do
not exist. `RiskBadge` was the tier-coloured badge; it was deleted deliberately,
and the app now renders tiers as plain text with no colour of their own, which is
what keeps the red medical notice from reading as "this result is bad". A handoff
that names it as an available building block is how the colour comes back.

## Assets imported

| Project path | Repo path |
| --- | --- |
| assets/ocrnew.png | OCRadar/Assets.xcassets/ocrnew.imageset/OCRadarNewCircle.png |
| assets/ocr-circle.png | OCRadar/Assets.xcassets/OCR-Circle.imageset/OCR-Circle.png |

## Not yet ported

The redesign lives in `OCRadarScreen.dc.html` only. The Swift restyle of
`OCRadarKit/Sources/OCRUI/` (including `.preferredColorScheme(.dark)` on
`RootView`, the custom tab bar, and keeping `RootView(classifier:)` intact)
has not been written yet.
