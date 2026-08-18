# Submitting OCRadar to the App Store

This is engineering documentation, not legal advice. It records how the app is
built and what that means for review; it cannot tell you whether OCRadar is a
regulated medical device in any jurisdiction you ship to. **Have counsel review
the app, the listing copy, and the privacy policy before you submit.** Where
something is genuinely unresolved, this document says so rather than implying it
is handled — the [outstanding work](#outstanding-work-before-you-can-submit)
section is the honest list.

## The position, in one sentence

> OCRadar is an awareness tool, not a diagnosis. Only a dentist or physician can
> examine a lesion.

That is `MedicalDisclaimer.short` in
[`OCRadarKit/Sources/OCRCore/MedicalDisclaimer.swift`](../OCRadarKit/Sources/OCRCore/MedicalDisclaimer.swift),
verbatim. The app never says anything about itself that contradicts it, and the
listing must not either. A reviewer reads the result screen and the store
description, in that order, and judges the app by what it *asserts* — not by what
the fine print at the bottom disclaims.

## Words that must not appear in the listing

App Store Review applies Guideline 1.4.1 based on what an app appears to do. The
listing is evidence. These words are how an awareness tool gets read as a
diagnostic one:

**Never**, in the app name, subtitle, description, keywords, promotional text,
screenshot captions, preview video, or support-site copy:

`screen` · `screening` · `screen for` · `detect` · `detection` · `detector` ·
`diagnose` · `diagnosis` · `diagnostic` · `test for` · `assess` · `assessment` ·
`evaluate` · `evaluation` · `rule out` · `early detection` · `cancer screening` ·
`medical-grade` · `clinically validated` · `FDA` (except to say it has *not* been
reviewed) · `accuracy` or any percentage, unless you can produce the study behind
it (see [shipping a trained model](#if-you-ever-ship-a-trained-model))

**Avoid**, because they read clinical even when technically true: `analysis`,
`analyze`, `results`, `risk`, `AI doctor`, `check-up`, `exam`. "Scan" is
acceptable as the name of the camera step inside the app; keep it out of the
subtitle and keywords, where it reads as a medical scan.

**Use instead:** awareness, educational, notice, compare, visual similarity,
reference categories, looks similar to, ask a dentist, worth asking about.

A worked example of the difference:

| Don't write | Write |
|---|---|
| "Screen your mouth for oral cancer" | "Notice something in your mouth? See what it looks similar to." |
| "AI detects 5 types of oral lesions" | "Compares your photo with 5 reference categories, entirely on your device." |
| "Get an instant risk assessment" | "Get a plain next step: routine, worth asking about, or see a professional soon." |
| "92% accurate" | (say nothing about accuracy unless you can substantiate it) |

## The disclaimer in the App Store description

Two placements, both required.

**1. The first line of the description**, above the fold — before the "more"
truncation, so it is visible without a tap. Paste exactly:

```
OCRadar is an awareness tool, not a diagnosis. Only a dentist or physician can examine a lesion.
```

**2. A closing block at the end of the description.** Paste exactly — this is
`MedicalDisclaimer.full`, the same text the app shows at first launch and beside
every result. Using the identical wording is deliberate: a reviewer who compares
the listing with the running app should find no gap between them.

```
IMPORTANT

OCRadar is an awareness tool. It is here to help you notice something and decide whether to ask a professional about it.

It is not a medical device. It has not been reviewed or evaluated by the FDA or any other regulator.

It does not diagnose, screen for, or rule out any condition, including cancer. It compares your photo with reference images and shows you which categories look similar. That is all it does.

The comparison can be wrong in both directions. It can point at something completely harmless, and it can miss something serious.

Only a dentist or physician can examine a lesion. Never delay care because of what this app shows you. If something in your mouth concerns you, get it looked at — whatever this app says.
```

If the app copy is ever revised, revise this block from
`MedicalDisclaimer.full` again rather than editing it in App Store Connect. One
wording, one source.

**Subtitle** (30 characters): must carry the framing, not a claim. "An awareness
tool for your mouth" (28) works. Do not use the subtitle for the disclaimer — it
is too short to say anything honest about limits, and a truncated disclaimer is
worse than none.

**Keywords**: none of the banned words above. Buying visibility on "oral cancer
screening" is the single fastest way to get rejected under 1.4.1, and under 2.3.7
if the keywords describe functionality the app does not have.

**Screenshots**: whatever the result screen shows in a screenshot is a claim.
Do not crop out the next-step guidance or the medical notice to make the layout
prettier. If a screenshot is taken in demo mode, its output is derived from image
dimensions and means nothing — do not caption it as a real comparison.

## Suggested App Review Notes

Paste into App Store Connect ▸ App Review Information ▸ Notes, adjusting the
bracketed parts. Short, specific, and volunteering the things a reviewer would
otherwise have to find:

```
WHAT THIS APP IS

OCRadar is an awareness and educational tool. The user photographs a spot in their mouth and the app shows which visual reference categories the photo looks most similar to, plus a plain next step ("Routine", "Worth asking about", "See a professional soon").

The app does not diagnose, screen for, detect, or rule out any condition. It never states what a lesion is. Every result is presented as a visual comparison, and the medical disclaimer appears on the result screen itself, not only in a footer.

It is not a medical device and has not been submitted to or reviewed by the FDA or any other regulator. Nothing in the app or its listing claims otherwise.

DISCLAIMER PLACEMENT

- First launch: a full-screen disclaimer must be acknowledged before any other screen is reachable. The acknowledgement button reads "I understand this is not a diagnosis".
- Camera screen, before the shutter: "This looks for visual similarity to reference photos. It cannot tell you what something is."
- Result screen, directly under the result and above everything else on it: "A visual comparison, not a diagnosis. Only a dentist or physician can tell you what this is." — in a bordered, red, warning-marked panel, with "Read the full notice" inside it opening the complete disclaimer.
- Scan history detail: the identical panel in the identical position beside the saved result.
- Home and Settings: a one-line version, with a link to the full disclaimer.

The full five-paragraph text is deliberately *not* also printed inline on the two
result screens. It is one tap from each of them, and it is the same text the app
blocks first launch with. Stacking it under a screen that already states the
frame in its own words is how a reader learns to skip both.

NO TRAINED MODEL SHIPS IN THIS BUILD  [delete this section if you bundle a model]

This build contains no trained machine-learning model. It runs a clearly labeled demo classifier whose output is derived from the image's pixel dimensions, not its content — so every photo of the same size returns identical numbers, and the app says exactly that wherever a demo score appears. The Home screen shows a "Demo mode — no trained model installed" card, Settings reports the Engine row as "Demo" with the version "mock-0.0.0", every demo result and saved demo record carries a notice, and the Home trend chart is labeled "demo placeholders" while all of its points are demo results. No claim is made about the demo output.

PRIVACY

There is no networking code in the app. Photos, thumbnails, and results are stored only in the on-device database and are never transmitted. There are no accounts, no analytics, no third-party SDKs, and no HealthKit access. No demo account is needed to review the app.

HOW TO EXERCISE THE FLOW

The camera path needs a physical device. On any device, Scan ▸ the photo-library button imports an existing photo instead and runs the identical flow, so a reviewer can reach the result screen without photographing anything.
```

## Guideline checklist

Status is honest: "Satisfied" means the code or copy already does it, "Your
move" means a human still has to do something.

| Guideline | What it asks | How OCRadar answers | Status |
|---|---|---|---|
| **1.4.1** — Physical Harm | Apps that could be used to diagnose get heightened scrutiny; medical claims must be accurate and not endanger a user | The app asserts visual similarity to reference categories and nothing else. It never names a condition as a finding, never reports severity, and never suggests a result substitutes for care. Tiers are next-step actions ("See a professional soon"), not health states. `MedicalDisclaimer` is the single source of the wording and call sites pass it verbatim, so no screen can drift into a claim | Satisfied in-app; **your move** on the listing copy, which is where 1.4.1 rejections usually originate |
| **1.4.1** — accuracy of claims | A medical claim must be substantiated | No accuracy, sensitivity, or specificity claim is made anywhere, and none may be added without evidence — see [below](#if-you-ever-ship-a-trained-model) | Satisfied while no model ships |
| **2.1** — App Completeness | Reviewable build, no placeholder content | The demo classifier is functional and labeled, not a placeholder — but see the outstanding item about shipping without a model, which is a product decision before it is a review one | **Your move** |
| **2.3.1 / 2.3.7** — Accurate metadata, keywords | No hidden features; metadata must match function | The DEBUG QA launch arguments are `#if DEBUG`-gated and are not present in a Release binary, so the reviewed build has no hidden entry points. Keywords must be free of the banned words above | Satisfied in code; **your move** on keywords |
| **2.5.1** — Public APIs only | No private APIs, no downloaded executable code | Only public frameworks: SwiftUI, SwiftData, AVFoundation, Vision, Core ML, PhotosUI, os.log. No private selectors, no dynamic patching. The Core ML model, when one exists, is compiled into the bundle at build time and never downloaded, so no interpreted or executable code arrives after review | Satisfied |
| **4.2** — Minimum Functionality | The app must do something useful | Camera capture, on-device inference, persistent history, per-category detail. Thin only in demo mode, which is the outstanding item | **Your move** |
| **5.1.1(i)** — Privacy policy | Every app needs one, linked in App Store Connect | Nothing to describe beyond on-device storage — but the policy still has to exist and be hosted | **Your move** — none exists in this repo |
| **5.1.1(ii)** — Permission strings | Purpose strings must explain use clearly | `INFOPLIST_KEY_NSCameraUsageDescription` reads "OCRadar uses the camera to photograph the inside of your mouth, then compares that photo with reference images on your device. Photos never leave your device." — no "analysis", and it states the on-device claim. No photo-library string is needed: the app uses `PhotosPicker`, which returns a chosen image without granting library access | Satisfied |
| **5.1.1(iii)** — Data minimization | Request only what you need | Camera only, and only at the moment of capture. No contacts, location, microphone, or notifications | Satisfied |
| **5.1.1** — Health data | Health information must not be used for advertising or shared with third parties, and may not be stored in iCloud without consent | Photos and results live only in the app's local SwiftData store. There is no networking code anywhere in the app, no analytics, no ad SDK, no third-party SDK of any kind, and no HealthKit or CloudKit use. Nothing to share, because nothing leaves the device | Satisfied — and this is a claim to protect: adding any backend, crash reporter, or sync makes 5.1.1 and 5.1.2 live questions again |
| **5.1.1(ix)** — Health research | Human-subject research needs consent and ethics review | The app conducts no research and collects nothing. If you ever gather images to improve a model, this clause and an IRB become your problem | Satisfied today |
| **5.1.2** — Data use and sharing | No sharing without consent | Nothing is transmitted | Satisfied |
| **Privacy manifest** (App Store requirement, not a guideline number) | Declare required-reason API use in `PrivacyInfo.xcprivacy` | `OCRadar/PrivacyInfo.xcprivacy` declares `NSPrivacyTracking` false, no tracking domains, an empty collected-data list, and the one required-reason API the app touches: `NSPrivacyAccessedAPICategoryUserDefaults` with reason `CA92.1`, for `@AppStorage("hasAcknowledgedDisclaimer")`. The app target's synchronized folder picks it up, so it ships in the bundle | Satisfied — re-audit if any file-timestamp, disk-space or system-boot API is ever added |

App Store Connect fields that follow from the same position:

- **Privacy nutrition label**: "Data Not Collected" is accurate today. It stops
  being accurate the moment anything is uploaded.
- **Age rating questionnaire**: answer the medical/treatment-information question
  honestly. The app does present health-adjacent educational content. Understating
  it to protect a lower rating is the kind of metadata problem that costs more
  than the rating would have.
- **Category**: Medical is the accurate fit; Health & Fitness is defensible for a
  purely educational framing. Choosing a category to dodge scrutiny does not
  work — 1.4.1 is applied to what the app does, not where it is filed.

## If you ever ship a trained model

Everything above assumes the shipping build makes no claim about performance.
Bundling real weights changes that, and the burden lands entirely on you:

- **Any performance number must be substantiated.** If the listing, the app, or
  the README says the model is accurate, or how accurate, you need a held-out
  evaluation you can hand a reviewer: dataset, size, how the split was made, and
  the metric. `ml/README.md` insists on macro recall and per-class recall for
  exactly this reason — a headline accuracy figure over an imbalanced set is not
  evidence.
- **Describe the training data.** Where the images came from, the consent and
  licensing basis, who applied the reference labels and their qualifications, and
  which populations are represented. A model evaluated on one range of mucosal
  tones and shipped to everyone is a harm, not a caveat.
- **The safest position is still to claim nothing.** A model can improve what the
  app shows without the app ever asserting how well it performs. Silence needs no
  substantiation.
- **Re-check device status with counsel.** Performance claims are one of the
  things that move a product from "general wellness" toward a regulated device,
  in the US and under EU MDR alike. This is exactly the point to ask, not after.

## Outstanding work before you can submit

Concrete, in rough order of how likely each is to block:

1. **Decide what ships in the box.** This build contains no trained model, so a
   user who downloads it gets output derived from image dimensions. Demo mode is
   labeled, but shipping an app whose core function is a stand-in is both a 2.1 /
   4.2 exposure and a bad user experience. Either bundle a model (and read the
   section above) or reconsider whether this build is the submission.
2. **Write and host a privacy policy**, and put the URL in App Store Connect.
   Required for every app, even one that collects nothing.
3. **Write the listing copy against the word list above**, then reread it
   pretending to be a reviewer who has seen the result screen and nothing else.
4. **Set a support URL and contact.** `contact@ocradar.com` is the address used
   elsewhere in the repo.
5. **Have counsel review** the listing, the disclaimer, the privacy policy, and
   the regulatory question of whether this is a device in each market you ship to.
   Nothing in this repository is a substitute for that.

## If the app is rejected

Rejections under 1.4.1 usually quote a specific line of metadata or a specific
screen. Fix the assertion, not the disclaimer: adding another warning to a screen
that claims too much does not change what it claims. Reply in Resolution Center
with the corrected wording and a pointer to where in the app the same wording
appears — the consistency between the app and the listing is the strongest thing
this project has to offer a reviewer.
