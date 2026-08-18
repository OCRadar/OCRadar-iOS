# OCRadar ML pipeline

PyTorch training and Core ML export for OCRadar's on-device image classifier.
The output of this pipeline — `OralLesionClassifier.mlpackage` and
`ModelManifest.json` — is what the app's `CoreMLLesionClassifier.bundled()`
loads at launch; when neither is bundled, the app falls back to a
deterministic mock.

What the model does, in the app's own terms: it scores how similar a photo is
to each of a set of **reference categories**. The app reports that similarity
and nothing more. It does not screen for, detect, diagnose, or rule out any
condition, and no output of this pipeline may be presented as if it did — see
[Ethics and intended use](#ethics-and-intended-use) below, and
[`../docs/APP_STORE.md`](../docs/APP_STORE.md) if you are shipping.

The manifest schema and the class metadata here mirror
`OCRadarKit/Sources/OCRCore/ModelManifest.swift`. If you change one side,
change the other.

## Dataset layout

```
data/
  train/
    healthy/*.jpg
    aphthous_ulcer/*.jpg
    lichen_planus/*.jpg
    leukoplakia/*.jpg
    erythroplakia/*.jpg
  val/            # optional; same class directories as train/
    ...
```

Rules:

- Directory names under `train/` are the class ids. They are embedded in the
  Core ML model and must match the keys in your labels YAML (see
  `labels.example.yaml`) and, ultimately, the `id` fields in
  `ModelManifest.json`.
- If `data/val` is absent, pass `--val-split` (default 0.15) and a seeded
  random split is carved out of `data/train`.
- Any image format Pillow reads works; JPEG and PNG are typical.

## Setup

```bash
cd ml
python3 -m venv .venv
source .venv/bin/activate
pip install -e .

# Verify the environment (no dataset or downloads needed):
python -m ocradar_ml.selfcheck
```

`pip install -e .` also installs `ocradar-train`, `ocradar-export`, and
`ocradar-selfcheck` as console commands, interchangeable with the
`python -m ocradar_ml.<module>` forms below.

## Quickstart: train, export, install

Train (from-scratch compact CNN, the default):

```bash
python -m ocradar_ml.train \
  --data data \
  --labels labels.example.yaml \
  --epochs 40 \
  --batch-size 32 \
  --out runs/exp
```

Passing `--labels` is optional but recommended: it verifies up front that
every class directory has display metadata, so export cannot fail after hours
of training. The run directory collects `classes.json` (the class order —
do not edit it), `best.pt` (best validation macro recall), `last.pt`, and
`history.json` (per-epoch accuracy, macro recall, per-class recall, and
confusion matrices).

Export to Core ML:

```bash
python -m ocradar_ml.export \
  --checkpoint runs/exp/best.pt \
  --classes runs/exp/classes.json \
  --labels labels.example.yaml \
  --model-version 1.0.0 \
  --out dist
```

This writes `dist/OralLesionClassifier.mlpackage` (FP16 ML Program; takes raw
RGB pixels, normalization is baked in) and `dist/ModelManifest.json`.

Install into the app:

```bash
mkdir -p "../OCRadar/Resources/ML"
cp -R "dist/OralLesionClassifier.mlpackage" "../OCRadar/Resources/ML/"
cp "dist/ModelManifest.json" "../OCRadar/Resources/ML/"
```

The Xcode synchronized folder picks both files up automatically and compiles
the mlpackage into the app bundle. The Swift loader expects exactly these
names: `OralLesionClassifier` and `ModelManifest.json`. Rebuild the app and
`CoreMLLesionClassifier.bundled()` replaces the mock.

## Ethics and intended use

- **Visual similarity, never diagnosis.** The model's output is a similarity
  score against reference categories, which the app presents as an awareness
  prompt: something to ask a professional about. Nothing in this pipeline or
  its outputs constitutes medical advice, diagnosis, or treatment, and the
  comparison can be wrong in both directions — it can point at something
  completely harmless, and it can miss something serious. `MedicalDisclaimer`
  in OCRCore holds the canonical wording; every word this pipeline emits into
  the manifest has to be consistent with it.
- **Write class metadata that describes the category, not the person.** A
  `summary` in your labels YAML says what the reference category looks like
  and what to do next. It must not say what a finding is, how likely it is to
  be anything, or what it may become. `riskLevel` is next-step guidance —
  `low` / `moderate` / `high` render in-app as "Routine" / "Worth asking
  about" / "See a professional soon" — so choose it by asking how soon
  someone should raise this with a professional, not how severe it is.
  `labels.example.yaml` is the template; follow its wording, not just its
  shape.
- **Source data responsibly.** Train only on images that were collected with
  informed consent for this use, under an appropriate license or data-use
  agreement, and with personally identifying information removed. Reference
  labels should come from qualified professionals, not crowd-sourcing.
- **Check who the model works for.** Evaluate performance across skin and
  mucosal tones, age groups, and capture conditions before shipping; a model
  that underperforms for some populations causes real harm, and "it is only
  an awareness tool" does not make that acceptable.
- **If you ship a trained model, you own its claims.** The moment real
  weights are in the bundle, any statement about how well it works — in the
  app, the README, or an App Store listing — has to be backed by a held-out
  evaluation you can produce, with the training data described. Keep the run
  directory, `history.json`, and your dataset provenance notes.

## Practical tips

- **Class balance.** Weighted cross-entropy (on by default, derived from
  training-set frequencies) softens moderate imbalance, but it cannot
  conjure signal from a class with a handful of images. Aim for real balance
  when collecting; the rare categories that carry the most urgent next step,
  like erythroplakia, are exactly the ones you cannot afford to under-train.
- **Model selection is macro recall,** not accuracy, for the same reason: a
  model must not buy accuracy by ignoring rare categories. Watch the
  per-class recall lines in the training log, not just the headline number.
- **Dataset sizes.** Below roughly 300 images per class, expect the
  from-scratch `oralnet` to struggle; a few hundred per class is a workable
  floor and 1,000+ per class is where results get dependable. Report-worthy
  evaluation needs a held-out `data/val` (or better, a separate test set)
  from different patients than training — never split one patient's photos
  across train and val.
- **When to try the MobileNet baseline.** `--arch mobilenet_v3_small
  --pretrained` starts from ImageNet weights and usually wins when data is
  scarce (under ~500 images per class) or as a sanity check: if `oralnet`
  trained from scratch lags far behind the pretrained baseline, you need more
  data or more epochs, not a bigger custom net.
- **Throughput.** Training runs on CUDA, Apple Silicon (MPS), or CPU, with
  mixed precision on the first two. Batch size 32 at 384x384 fits comfortably
  in 8 GB; halve it if you hit memory limits and consider `--lr 2e-4` to
  match.
- **Reproducibility.** `--seed` controls Python, NumPy, and torch seeding
  plus the val split and shuffle order. Keep the seed with your run notes so
  a result can be reproduced.
