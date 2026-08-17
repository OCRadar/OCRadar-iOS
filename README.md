# OCRadar

On-device oral-lesion screening for iPhone: photograph a spot in your mouth and get risk-tiered guidance in seconds, with nothing ever leaving the device.

> [!WARNING]
> **OCRadar is not a medical device.** It is a screening aid and does not provide medical advice, diagnosis, or treatment. Results come from an on-device image model and **can be wrong in either direction**. Always consult a dentist or physician about any lesion, discoloration, or symptom that concerns you — regardless of what this app reports. The app enforces this framing in-product: a first-launch disclaimer must be acknowledged before use, and the full disclaimer is repeated with every result, in scan history, and in Settings.

## Features

- **Live camera capture** — back wide-angle camera with a glass shutter, gravity-aligned photo orientation, and an interruption-aware session state machine (phone calls, Split View, system pressure, permission denial all surface as distinct UI states).
- **Photo-library import** — analyze an existing photo via `PhotosPicker`, with EXIF orientation normalized before inference. This is also the fallback on devices without a camera (e.g. the Simulator).
- **Capture review** — every photo gets a retake/analyze step before anything runs.
- **On-device inference behind a single seam** — the `LesionClassifying` protocol is implemented by a Core ML + Vision backend when a trained model is bundled, and by a deterministic mock otherwise. The mock ships with five demo classes (healthy, aphthous ulcer, lichen planus, leukoplakia, erythroplakia).
- **Risk-tiered results** — top class with a probability ring, per-class score bars, low/moderate/high risk badges, plain-language summaries sourced from the model manifest, and a see-a-professional callout that escalates for moderate/high tiers.
- **Scan history** — every analysis is saved locally with SwiftData (JPEG thumbnails in external storage), with a detail view and swipe-to-delete.
- **Private by construction** — all analysis happens on device; the app contains no networking code. Photos and results never leave the phone.
- **Demo mode, clearly labeled** — until a trained model is installed, the Home tab shows a "Demo mode — no trained model installed" card and Settings reports the engine as "Demo (mock)". Demo results carry no medical meaning.
- **Liquid Glass UI** — SwiftUI throughout, portrait iPhone, a single glass-card treatment shared across all screens.

## Requirements

- **Xcode 27** (the project was created with Tools 27.0 and uses project format 77)
- **iOS 26** deployment target; iPhone only, portrait orientation
- Swift 6 language mode; the `OCRadarKit` package uses Swift tools 6.2
- A **physical iPhone** for camera capture — the Simulator has no camera, so the app offers photo-library import there instead
- For model training only: **Python 3.10+** with PyTorch ≥ 2.5 and coremltools ≥ 8.0 (see `ml/pyproject.toml`); training runs on CUDA, Apple Silicon (MPS), or CPU

## Getting started

```bash
git clone <repo-url>
cd OCR-iOS
open OCRadar.xcodeproj
```

Select the `OCRadar` scheme and run. No further setup is needed: **without a trained model the app launches in clearly-labeled demo mode**, backed by a deterministic mock classifier, so every screen is fully navigable. Install a trained model (next section) and the app loads it in the background at launch, switching from demo mode to real Core ML inference as soon as it is ready.

## Training your own model

The full pipeline — dataset layout, ethics and intended-use guidance, and practical training tips — is documented in [`ml/README.md`](ml/README.md). The short version, after a one-time `cd ml && python3 -m venv .venv && source .venv/bin/activate && pip install -e .`:

```bash
# 1. Train (from-scratch compact CNN by default; --labels validates metadata up front)
python -m ocradar_ml.train --data data --labels labels.example.yaml --epochs 40 --out runs/exp

# 2. Export to Core ML (FP16 ML Program + manifest)
python -m ocradar_ml.export --checkpoint runs/exp/best.pt --classes runs/exp/classes.json \
  --labels labels.example.yaml --model-version 1.0.0 --out dist

# 3. Install into the app
mkdir -p ../OCRadar/Resources/ML
cp -R dist/OralLesionClassifier.mlpackage dist/ModelManifest.json ../OCRadar/Resources/ML/
```

The export lands in **`OCRadar/Resources/ML/`** as `OralLesionClassifier.mlpackage` plus `ModelManifest.json` — the loader expects exactly those names. The app target's synchronized folder picks both up automatically; rebuild and `CoreMLLesionClassifier.bundled()` replaces the mock. `python -m ocradar_ml.selfcheck` verifies the Python environment without any dataset or downloads.

## Repository layout

```
OCR-iOS/
├── OCRadar.xcodeproj/       # Xcode project: app target + local OCRadarKit package
├── OCRadar/                 # App target — a thin shell
│   ├── OCRadarApp.swift     # @main: classifier selection + SwiftData container
│   ├── Assets.xcassets/     # App icon, accent color, brand images
│   ├── Preview Content/
│   └── Resources/ML/        # (created by you) trained model + manifest live here
├── OCRadarKit/              # Local Swift package — all of the real code
│   ├── Package.swift
│   ├── Sources/
│   │   ├── OCRCore/         # Domain types + the classifier seam (UI-free)
│   │   ├── OCRCapture/      # AVFoundation camera session + SwiftUI preview
│   │   ├── OCRVision/       # Core ML / Vision inference backend
│   │   └── OCRUI/           # All screens and components (MainActor by default)
│   └── Tests/
│       ├── OCRCoreTests/    # Manifest, classification, scan-record, mock tests
│       └── OCRVisionTests/  # Preprocessing + bundled-model loading tests
└── ml/                      # PyTorch training + Core ML export pipeline
    ├── README.md            # The full training guide
    ├── labels.example.yaml  # Class metadata (mirrors the app's mock manifest)
    ├── pyproject.toml
    └── ocradar_ml/          # train / export / selfcheck CLIs + model, data, labels
```

## Architecture

The app target is deliberately thin: one file that starts with `MockLesionClassifier`, hands it to `RootView`, and swaps in `CoreMLLesionClassifier.bundled()` from a background task when a model is in the bundle (model loading never blocks launch). Everything else lives in the `OCRadarKit` package, split so that UI, capture, and inference stay decoupled — `OCRUI` never imports `OCRVision`; the two only meet through the `LesionClassifying` protocol defined in `OCRCore` and injected via a SwiftUI environment key.

```mermaid
graph TD
    App["OCRadar app shell"] --> OCRUI
    App --> OCRVision
    App --> OCRCore
    OCRUI --> OCRCore
    OCRUI --> OCRCapture["OCRCapture"]
    OCRVision --> OCRCore
```

See [`docs/ARCHITECTURE.md`](docs/ARCHITECTURE.md) for module responsibilities, the model + manifest contract, the scan data flow, the concurrency model, and how to add a new lesion class end-to-end.

## Testing

Tests use the Swift Testing framework (`@Suite` / `@Test`) and live in the package (`OCRCoreTests`, `OCRVisionTests`); the shared `OCRadar` scheme auto-creates a test plan that includes them. The package targets iOS, so tests run on an iOS Simulator.

Build everything, including test targets, without needing a simulator runtime:

```bash
xcodebuild build-for-testing \
  -project OCRadar.xcodeproj -scheme OCRadar \
  -destination 'generic/platform=iOS Simulator'
```

To actually run the tests, install an iOS 26 simulator runtime once (Xcode ▸ Settings ▸ Components, or `xcodebuild -downloadPlatform iOS`), then:

```bash
xcodebuild test \
  -project OCRadar.xcodeproj -scheme OCRadar \
  -destination 'platform=iOS Simulator,name=<device>'
```

where `<device>` is any device listed by `xcrun simctl list devices available`.

For the ML side, `python -m ocradar_ml.selfcheck` builds both supported architectures and runs a forward pass — no dataset or downloads required.

## License

**Proprietary — all rights reserved.** Copyright © 2026 OCRadar.

This repository is publicly visible, but it is **not open source**. No permission is granted to use, copy, modify, distribute, or create derivative works from any part of it — including the source, the ML pipeline, trained models, and the design system. Public visibility does not grant a license, and neither does forking or cloning.

See [LICENSE](LICENSE) for the full terms. Licensing inquiries: contact@ocradar.com
