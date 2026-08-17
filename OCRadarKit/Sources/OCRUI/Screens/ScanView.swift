import CoreGraphics
import OCRCapture
import OCRCore
import PhotosUI
import SwiftData
import SwiftUI
import UIKit

/// Capture tab: a gradient header band over a rounded camera stage that holds
/// the live preview, a radar-and-reticle framing aid, photo-library import, a
/// capture-review step, and on-device analysis that saves each result to
/// History.
///
/// Layout follows the design spec's Scan screen: band 150 tall from the top of
/// the screen, stage inset 16 with 166 above and 104 below so it clears the
/// floating tab bar.
///
/// This is the one screen where Liquid Glass earns its keep: the controls float
/// over a live camera feed or a captured photo, so there is real content for the
/// glass to refract. Five surfaces qualify — the status pill, the framing
/// caption, the library circle, the shutter ring and the analyzing capsule. The
/// gradient band above, the stage itself and the three camera-fallback layouts
/// stay flat and opaque, exactly as `design/README.md` specifies, and so do
/// "Retake" and "Analyze": see `reviewActions(for:)` for the measurement that
/// put them back.
///
/// Every glass surface here carries a tint rather than being left bare, because
/// "adapts to its backdrop" cuts both ways — the backdrop can also be a
/// blown-out photograph, and untinted glass follows it straight up into the
/// label. The three that must hold a light label over an arbitrary frame — the
/// status pill, the framing caption and the analyzing capsule — are tinted
/// toward `stageFill`; the shutter ring keeps the accent, since its solid
/// gradient core carries the control whatever the ring does. The per-surface
/// numbers are on each one.
///
/// The material itself is `ocrGlass(_:...)` in `Components/OCRGlass.swift`, so
/// this screen, the tab bar and the sheet headers cannot drift into three
/// different ideas of what the app's glass is. The single `reduceTransparency`
/// read below feeds every call here, so two halves of one control can never
/// disagree about which treatment they are in.
///
/// **Reduce Transparency falls back to `surfaceRaised`, not to the design's
/// washes.** Everywhere else in the app the fallback is literally the flat fill
/// the glass replaced, because that fill was measured against a known backdrop.
/// This screen has no known backdrop: the stage is a live camera frame or a
/// photograph the user chose. The spec's `white 8%` pill and `accent 16%`
/// analyzing capsule were drawn over a dark stand-in stage, and over a bright
/// frame they composite to the exact washes the tints above exist to fix —
/// measured on the `-qaScanStage review` frame, the pill's `numeralMuted` label
/// falls to 3.17:1 and the capsule's white label to 3.31:1, against 7.50:1 and
/// 8.07:1 on the glass path. Turning an accessibility setting **on** must not
/// make those labels harder to read. `surfaceRaised` (`#2C2737` since the ink
/// pass) is opaque, so it is the one treatment whose contrast does not depend
/// on the photograph at all: `numeralMuted` on it measures 11.68:1 and white
/// 14.46:1, whatever is underneath. It is also the token "Retake" already uses
/// on this same stage, for this same reason.
struct ScanView: View {
    @Environment(\.lesionClassifier) private var classifier
    @Environment(\.modelContext) private var modelContext
    @Environment(\.openURL) private var openURL

    /// Reduce Transparency swaps every glass surface below for the flat opaque
    /// fill it replaced. Read once here rather than in each helper so the
    /// fallback can never diverge between two pieces of the same control.
    @Environment(\.accessibilityReduceTransparency) private var reduceTransparency

    @State private var camera = CameraService()
    @State private var capturedImage: CGImage?
    @State private var pickerItem: PhotosPickerItem?
    @State private var isCapturing = false
    @State private var isAnalyzing = false
    @State private var presentedOutcome: AnalysisOutcome?
    @State private var errorMessage: String?

    /// Height of the review actions and the analyzing capsule. Scaled so the
    /// labels stay inside their capsules at large Dynamic Type sizes.
    @ScaledMetric(relativeTo: .body) private var actionHeight: CGFloat = 52

    /// Height of the status pill, for the same reason as `actionHeight`.
    @ScaledMetric(relativeTo: .caption) private var pillHeight: CGFloat = 30

    /// Height of a **lone** call to action, matching `OCRPrimaryButtonStyle`'s
    /// own default and Home's hero capsule.
    ///
    /// The three camera-fallback stages used to pin their buttons at 50 — a
    /// third height for one role, and the only one `design/README.md` never
    /// names. They take this instead. `actionHeight` stays at the spec'd 52
    /// because it is the paired Retake/Analyze row rather than a lone CTA, and
    /// the two roles are now the only two capsule heights in the app.
    private static let ctaHeight: CGFloat = 54

    /// Gap between the top of the stage and the top of the radar's box: the
    /// spec centres the radar at y 206 in stage coordinates, and the radar box
    /// is 250 tall.
    private let radarBoxTop: CGFloat = 81

    var body: some View {
        ZStack {
            OCRAmbientBackground()

            VStack(spacing: Theme.spacingM) {
                OCRHeaderBand(
                    title: "Scan",
                    subtitle: "Nothing leaves your iPhone",
                    fixedHeight: 150
                ) {
                    Text(stepLabel)
                }

                stage
                    .padding(.horizontal, Theme.stageInset)
                    .padding(.bottom, 104)
            }
            // Both edges: the band is measured from the top of the screen
            // (150 tall, stage top 166) and the stage's 104 bottom inset is
            // measured from the bottom of the screen, not from the home
            // indicator — otherwise the stage lost 34pt of height.
            .ignoresSafeArea()
        }
        .task {
            // No-op unless a `-qaScanStage` argument is present, and compiled
            // out of Release entirely.
            applyQAScanStage()
            await camera.start()
        }
        .onDisappear { camera.stop() }
        .onChange(of: pickerItem) { _, item in
            guard let item else { return }
            Task { await loadPickedPhoto(item) }
        }
        .sheet(item: $presentedOutcome, onDismiss: { capturedImage = nil }) { outcome in
            ResultView(result: outcome.result)
        }
        .alert(
            "Something Went Wrong",
            isPresented: isShowingError,
            actions: {
                Button("OK", role: .cancel) {}
            },
            message: {
                Text(errorMessage ?? "")
            }
        )
    }

    /// "Step 1 of 2" while framing, "Step 2 of 2" once a photo is in review.
    private var stepLabel: String {
        capturedImage == nil ? "Step 1 of 2" : "Step 2 of 2"
    }

    // MARK: - Stage

    /// The rounded, bordered panel every scan state lives inside.
    private var stage: some View {
        ZStack {
            stageContent
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Theme.stageFill)
        .clipShape(.rect(cornerRadius: Theme.stageCorner))
        .overlay {
            // The design's 1px `stageBorder`, with the top arc lit by
            // `surfaceEdge` and the light gone by 45% down. `stageFill` now
            // sits *below* the canvas rather than above it, so the stage reads
            // as a well cut into the page — and a well is lit along its top lip
            // and dark along its floor. A flat border of one colour all the way
            // round was the alternative, and a closed even outline is exactly
            // what system chrome looks like.
            RoundedRectangle(cornerRadius: Theme.stageCorner)
                .strokeBorder(
                    LinearGradient(
                        stops: [
                            .init(color: Theme.surfaceEdge, location: 0),
                            .init(color: Theme.stageBorder, location: 0.45)
                        ],
                        startPoint: .top,
                        endPoint: .bottom
                    ),
                    lineWidth: 1
                )
                // Decorative and inert, like every other decorative layer in
                // the pass (`ocrTopEdgeHighlight`, `ocrPanelSpill`,
                // `OCRAmbientBackground`). This one is an *overlay* on the
                // stage, so it sits on top of the shutter, the library picker,
                // Retake and Analyze — the one decorative layer most exposed to
                // the rule.
                .allowsHitTesting(false)
                .accessibilityHidden(true)
        }
    }

    /// QA-automation hook (debug builds only): `-qaScanStage live` forces the
    /// framing layout even where no camera exists. The simulator always reports
    /// `.unavailable`, so without this the radar, reticle, shutter and status
    /// pill can never be seen — let alone measured — on a screenshot sweep.
    private var forcesLiveStage: Bool {
        #if DEBUG
        UserDefaults.standard.string(forKey: "qaScanStage") == "live"
        #else
        false
        #endif
    }

    /// The other half of the same hook: `-qaScanStage review` and
    /// `-qaScanStage analyzing` drop a stand-in photo onto the stage and, for
    /// the second, pin the analyzing state.
    ///
    /// Same argument as `forcesLiveStage`. Reaching either state for real needs
    /// a camera the simulator does not have, or a tap through the system photo
    /// picker that a headless sweep cannot perform — so "Retake", "Analyze" and
    /// the analyzing capsule were the three controls on this screen that could
    /// never be looked at. `analyzing` deliberately does *not* call `classify`:
    /// it holds the capsule on screen to be measured instead of letting the
    /// mock resolve it in a few milliseconds.
    private func applyQAScanStage() {
        #if DEBUG
        let stage = UserDefaults.standard.string(forKey: "qaScanStage")
        guard stage == "review" || stage == "analyzing" else { return }
        capturedImage = QASampleImage.gradient()
        isAnalyzing = stage == "analyzing"
        #endif
    }

    @ViewBuilder
    private var stageContent: some View {
        if let capturedImage {
            reviewStage(for: capturedImage)
        } else if forcesLiveStage {
            liveStage
        } else {
            switch camera.state {
            case .idle, .configuring, .running:
                liveStage
            case .denied:
                deniedStage
            case .unavailable:
                unavailableStage
            case .failed(let message):
                failedStage(message)
            }
        }
    }

    // MARK: - Live

    private var liveStage: some View {
        GeometryReader { proxy in
            ZStack {
                CameraPreview(service: camera)
                    .accessibilityHidden(true)

                VStack(spacing: 0) {
                    // Absorbs first so the framing aid keeps its 81pt offset on
                    // a tall stage and compresses on a short one.
                    Spacer(minLength: 0)
                        .frame(maxHeight: radarBoxTop)

                    framingAid(
                        diameter: radarDiameter(inStageHeight: proxy.size.height),
                        acquiring: isAcquiringCamera
                    )

                    // The one label on this stage that had no backdrop of its
                    // own. `textSecondary` measures 6.75:1 over `stageFill`,
                    // which is the number a dark stand-in stage gives it — but
                    // this text is drawn on the *live frame*, and over a
                    // blown-out one it measures **2.93:1**, under the 4.5:1
                    // floor this file enforces on the pill (3.06:1 rejected),
                    // the library circle (2.47:1) and the analyzing capsule
                    // (2.47:1). It takes the treatment those established
                    // instead: `numeralMuted` on `stageFill`-tinted glass —
                    // ~7.4:1 on the same material the pill measures 7.50:1 on —
                    // falling back to the opaque `surfaceRaised` (11.7:1) under
                    // Reduce Transparency, exactly as they do.
                    //
                    // The plate hugs the copy rather than spanning the stage:
                    // `Text` takes its ideal width, so the glass is only as wide
                    // as the two lines and the framing view stays open.
                    Text("Frame the area that concerns you\nHold steady in good light")
                        .font(.system(size: 14))
                        .foregroundStyle(Theme.numeralMuted)
                        .multilineTextAlignment(.center)
                        .ocrBodyLeading(size: 14)
                        .padding(.horizontal, 14)
                        .padding(.vertical, 9)
                        .ocrGlass(
                            .rect(cornerRadius: Theme.rowCorner),
                            tint: Theme.stageFill.opacity(0.5),
                            fallback: Theme.surfaceRaised,
                            reduceTransparency: reduceTransparency
                        )
                        .padding(.horizontal, Theme.spacingL)

                    Spacer(minLength: Theme.spacingM)

                    captureControls
                }
                .padding(.bottom, 26)

                if camera.state == .running || forcesLiveStage {
                    statusPill(text: "Camera ready", dot: Theme.salmon)
                }
            }
            .frame(width: proxy.size.width, height: proxy.size.height)
        }
        // The device has no flash control in `CameraService`, so the spec's
        // flash toggle is omitted rather than shipped as a dead button.
    }

    /// Everything below the framing aid — caption, the 16pt gap, the 78pt
    /// shutter row and the 26pt bottom padding — is incompressible, so the
    /// radar is what has to give on a short stage. On a 667pt device the stage
    /// is only 397 tall and the design's 250pt radar put the layout ~10pt over
    /// budget, which the stage's `clipShape` cut off rather than scrolled.
    private func radarDiameter(inStageHeight height: CGFloat) -> CGFloat {
        let reservedBelowRadar: CGFloat = 165
        guard height > 0 else { return Self.designRadarDiameter }
        return min(
            Self.designRadarDiameter,
            max(Self.minimumRadarDiameter, height - reservedBelowRadar)
        )
    }

    private static let designRadarDiameter: CGFloat = 250
    private static let minimumRadarDiameter: CGFloat = 150
    /// The design's 186pt reticle inside its 250pt radar box.
    private static let reticleRatio: CGFloat = 186 / 250

    /// Whether the session is still coming up. This used to put a stock
    /// `ProgressView` in the middle of the stage — a grey system spinner
    /// floating on a dark rectangle, the single most borrowed-looking thing on
    /// the screen, and redundant besides: the radar arm behind it was already
    /// sweeping.
    ///
    /// The state is carried by the framing aid instead. See `framingAid`.
    private var isAcquiringCamera: Bool {
        guard !forcesLiveStage else { return false }
        return camera.state == .idle || camera.state == .configuring
    }

    /// Radar and reticle share one `ZStack`, so their centres coincide — the
    /// spec calls this out twice, and the reticle keeps its ratio to the radar
    /// when the radar is scaled down for a short stage.
    ///
    /// `acquiring` is how this screen says "not ready yet" in its own
    /// vocabulary rather than the system's. The radar sweeps from the moment
    /// the stage appears; the four accent brackets — the element that means
    /// *aim here* — only join it once the session is actually running. Acquire,
    /// then lock. It costs no new copy, no new colour and no new motion: the
    /// brackets are simply not drawn yet, so there is nothing here for Reduce
    /// Motion to gate, and the shutter is independently disabled until the same
    /// moment.
    private func framingAid(diameter: CGFloat, acquiring: Bool) -> some View {
        ZStack {
            OCRRadar(diameter: diameter, sweeping: true)
                .opacity(0.55)

            OCRReticle()
                .frame(height: diameter * Self.reticleRatio)
                .padding(.horizontal, 40)
                .opacity(acquiring ? 0 : 1)
        }
        .frame(maxWidth: .infinity)
        .frame(height: diameter)
        .accessibilityHidden(true)
    }

    /// The library circle and the shutter are two glass siblings 40pt apart, so
    /// they share one `GlassEffectContainer`: it renders them in a single pass
    /// and lets them sample each other's edges instead of stacking two
    /// independent blurs over the same frame of camera feed. `spacing: 12` is
    /// well under the 40pt gap, so the two stay visually distinct rather than
    /// merging into one blob.
    private var captureControls: some View {
        GlassEffectContainer(spacing: 12) {
            HStack(spacing: 40) {
                libraryCircleButton

                shutterButton

                // Balances the library button so the shutter stays optically
                // centred in the stage.
                Color.clear
                    .frame(width: 48, height: 48)
                    .accessibilityHidden(true)
            }
        }
        .frame(maxWidth: .infinity)
    }

    /// Tinted toward `stageFill` for the same reason as the status pill it
    /// shares the stage with: untinted, this circle follows a bright camera
    /// frame up to around `#D8796E`, where its `numeralMuted` glyph measures
    /// 2.47:1 — under the 3:1 a non-text control needs. The two are the only
    /// chrome sitting directly on the live feed, so they take the same
    /// treatment rather than each guessing at one.
    ///
    /// The Reduce Transparency fallback is the opaque `surfaceRaised`, not the
    /// design's `white 8%` wash, for the reason in this type's doc comment: the
    /// wash rides up with the same bright frame and puts this glyph back at the
    /// 2.47:1 the tint was added to fix.
    private var libraryCircleButton: some View {
        // Read out of the closure: `PhotosPicker`'s label builder is
        // `@Sendable`, so the main-actor-isolated environment value cannot be
        // touched inside it. A captured `Bool` can.
        let isFlat = reduceTransparency
        return PhotosPicker(selection: $pickerItem, matching: .images) {
            // `.medium` and monochrome, the app's one glyph treatment.
            // `photo.on.rectangle` carries a hierarchical default, which drew
            // its two plates at two densities inside a single 48pt control.
            Image(systemName: "photo.on.rectangle")
                .font(.system(size: 21, weight: .medium))
                .symbolRenderingMode(.monochrome)
                .foregroundStyle(Theme.numeralMuted)
                .frame(width: 48, height: 48)
                .ocrGlass(
                    .circle,
                    tint: Theme.stageFill.opacity(0.5),
                    interactive: true,
                    fallback: Theme.surfaceRaised,
                    reduceTransparency: isFlat
                )
        }
        .buttonStyle(.plain)
        .accessibilityLabel("Choose a photo from your library")
    }

    /// The 60pt core stays solid `Theme.button` — it is the primary action on
    /// the screen and must never depend on what is behind it. Only the 78pt
    /// ring turns to glass.
    ///
    /// The ring uses `.regular` tinted with the accent, not `.clear`: clear
    /// glass has almost nothing to refract on the unlit stage (`stageFill`, with
    /// the ambient canvas behind it only a few L\* points brighter), where it
    /// rendered as an all-but-invisible smudge. Regular glass plus the design's
    /// 2pt accent ring keeps the shutter legible on an unstarted stage *and*
    /// over a bright live feed — the one treatment that survives both.
    private var shutterButton: some View {
        Button {
            Task { await capturePhoto() }
        } label: {
            ZStack {
                Circle()
                    .strokeBorder(Theme.accent.opacity(0.55), lineWidth: 2)
                Theme.button
                    .clipShape(.circle)
                    .frame(width: 60, height: 60)
            }
            .frame(width: 78, height: 78)
            .ocrGlass(
                .circle,
                tint: Theme.accent.opacity(0.16),
                interactive: true,
                fallback: Theme.accent.opacity(0.12),
                reduceTransparency: reduceTransparency
            )
        }
        .buttonStyle(.plain)
        .disabled(camera.state != .running || isCapturing)
        .accessibilityLabel("Capture photo")
    }

    /// Top-left capsule: a glass pill with a pulsing dot and one short line.
    ///
    /// **Tinted with `stageFill`, and that tint is the whole point.** Regular
    /// glass adapts to its backdrop, which cuts both ways: over the dark live
    /// stage untinted glass sampled `#2B2B2F` and the `#E8E6EC` label measured
    /// 11.4:1, but over the bright review photo the same material rode up to
    /// `#C86667` and the label fell to **3.06:1** — no better than the flat
    /// `white 8%` it replaced, which measured 3.06:1 on the same frame. Both
    /// are under the spec's floor.
    ///
    /// Tinting toward the stage's own `stageFill` stops the pill following a
    /// bright photo upward, so one treatment holds on a dark feed and a blown-out
    /// one alike. The label colour is unchanged.
    ///
    /// The Reduce Transparency fallback is the opaque `surfaceRaised`, not that
    /// `white 8%` — restoring it would restore the 3.06:1 this comment already
    /// rejects. See this type's doc comment.
    private func statusPill(text: String, dot: Color) -> some View {
        HStack(spacing: 8) {
            OCRStatusDot(color: dot, pulsing: true)
            Text(text)
                .font(.system(size: 12.5, weight: .medium))
                .foregroundStyle(Theme.numeralMuted)
        }
        .padding(.horizontal, 13)
        // Scaled: the 12.5pt label grows with Dynamic Type, and a hard 30
        // left it spilling out of the capsule onto the camera preview, where
        // nothing guarantees contrast.
        .frame(minHeight: pillHeight)
        .ocrGlass(
            .capsule,
            tint: Theme.stageFill.opacity(0.5),
            fallback: Theme.surfaceRaised,
            reduceTransparency: reduceTransparency
        )
        .accessibilityElement(children: .combine)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        .padding(Theme.stageInset)
    }

    // MARK: - Review

    private func reviewStage(for image: CGImage) -> some View {
        ZStack {
            Color.clear
                .overlay {
                    Image(decorative: image, scale: 1)
                        .resizable()
                        .scaledToFill()
                }
                .clipped()
                .accessibilityElement()
                .accessibilityLabel("Captured photo")

            VStack(spacing: 0) {
                Spacer(minLength: Theme.spacingM)

                if isAnalyzing {
                    // Its own container: the analyzing capsule is the only
                    // glass in this slot now that the two review buttons are
                    // flat again, and a container around a flat row would be a
                    // no-op that only reads as if something glassy lived there.
                    GlassEffectContainer(spacing: 12) {
                        analyzingCapsule
                    }
                } else {
                    reviewActions(for: image)
                }
            }
            .padding(.horizontal, Theme.stageInset)
            .padding(.bottom, 22)

            statusPill(text: "Review", dot: Theme.accent)
        }
    }

    /// Dark-tinted glass, and the one place this pass knowingly departs from a
    /// literal value in `design/README.md`.
    ///
    /// The spec draws this capsule as `rgba(199,123,232,.16)` — a purple wash
    /// over the captured photo. Measured on the stand-in frame that wash puts
    /// white 16/600 at **2.47:1**, and accent-tinted glass at **2.91:1**; the
    /// wash is light, the photo under it is light, and nothing in either
    /// treatment stops the two adding up. The same document sets the floor
    /// those numbers are failing (`all body text ≥4.5:1`), so the floor wins:
    /// tinted toward `stageFill` the capsule holds the label whatever the photo
    /// does.
    ///
    /// The purple is not lost — it moves to the pulsing accent dot, which the
    /// spec also calls for, and this now matches the status pill on the same
    /// stage. The Reduce Transparency fallback is the opaque `surfaceRaised`
    /// rather than the spec's 16% wash: the wash is the same 2.47:1 treatment
    /// this comment already rejects, and turning an accessibility setting on
    /// must not restore it. See this type's doc comment.
    private var analyzingCapsule: some View {
        HStack(spacing: 11) {
            OCRStatusDot(color: Theme.accent, pulsing: true)
            Text("Analyzing on device…")
                .font(.system(size: 16, weight: .semibold))
                .foregroundStyle(Theme.textPrimary)
        }
        .frame(maxWidth: .infinity, minHeight: actionHeight)
        .ocrGlass(
            .capsule,
            tint: Theme.stageFill.opacity(0.5),
            fallback: Theme.surfaceRaised,
            reduceTransparency: reduceTransparency
        )
        .accessibilityElement(children: .combine)
        .accessibilityLabel("Analyzing on device")
    }

    /// "Retake" and "Analyze" split the row 1 : 1.4, per the spec.
    ///
    /// **Both stay flat.** "Retake" was glass for one round of this pass and it
    /// was the clearest regression in it: over the review photo the material
    /// sampled `#D8796E` and white 16/600 fell to **3.05:1**, against the
    /// **14.46:1** the opaque `surfaceRaised` capsule guarantees on any photo.
    /// (White on `#2C2737`, recomputed. The **11.9:1** this used to quote was
    /// never right for this pair — it is near `numeralMuted`'s number, not
    /// white's — and it disagreed with the 14.x this same file states in its
    /// type doc. In a file whose whole argument is "measured, not estimated",
    /// a stale figure is what the next change gets checked against.)
    /// These two buttons sit on the largest, least predictable backdrop in the
    /// app — a full-bleed photograph the user chose — and an opaque capsule is
    /// the only thing that makes their contrast independent of it. Glass is for
    /// the small chrome floating *over* this stage, not for the two controls
    /// the whole screen resolves to. "Analyze" keeps the solid `buttonGradient`
    /// for the same reason, plus it must read as the primary.
    private func reviewActions(for image: CGImage) -> some View {
        GeometryReader { proxy in
            let gap = Theme.spacingS
            let retakeWidth = max(88, (proxy.size.width - gap) / 2.4)

            HStack(spacing: gap) {
                Button("Retake") {
                    capturedImage = nil
                }
                .buttonStyle(OCRSecondaryButtonStyle(height: actionHeight))
                .frame(width: retakeWidth)

                Button("Analyze") {
                    Task { await analyze(image) }
                }
                .buttonStyle(OCRPrimaryButtonStyle(height: actionHeight))
                .frame(maxWidth: .infinity)
            }
        }
        .frame(height: actionHeight)
    }

    // MARK: - Camera fallbacks

    private var deniedStage: some View {
        fallbackStage(
            struckThrough: true,
            title: "Camera access needed",
            message: "OCRadar uses the camera to photograph areas inside your mouth. Allow camera access in Settings to scan, or analyze a photo from your library instead."
        ) {
            Button("Open Settings") {
                if let url = URL(string: UIApplication.openSettingsURLString) {
                    openURL(url)
                }
            }
            .buttonStyle(OCRPrimaryButtonStyle(height: Self.ctaHeight))

            libraryPickerButton(title: "Choose Photo")
                // Stated rather than defaulted: this capsule is stacked
                // directly under the primary above it, and the secondary
                // style's own 52 default is the *paired-action* height, which
                // would have left two stacked capsules 2pt apart.
                .buttonStyle(OCRSecondaryButtonStyle(height: Self.ctaHeight))
        }
    }

    private var unavailableStage: some View {
        fallbackStage(
            struckThrough: false,
            title: "Camera unavailable",
            message: "No camera is available on this device. Choose a photo from your library to analyze instead."
        ) {
            libraryPickerButton(title: "Choose Photo")
                .buttonStyle(OCRPrimaryButtonStyle(height: Self.ctaHeight))
        }
    }

    private func failedStage(_ message: String) -> some View {
        fallbackStage(
            struckThrough: true,
            title: "Camera error",
            message: message
        ) {
            Button("Try again") {
                Task { await camera.start() }
            }
            .buttonStyle(OCRPrimaryButtonStyle(height: Self.ctaHeight))
        }
    }

    /// Shared blocked-camera layout: a small static radar glyph, a title, an
    /// explanation, and one or two capsule actions — centred in the stage.
    ///
    /// Deliberately **not** glass, primary or secondary. All three fallbacks
    /// mean there is no preview: the stage is a flat `stageFill` panel on the
    /// ink canvas, so glass has nothing to refract and renders as a muddy grey
    /// wash that reads *less* clearly than `surfaceRaised` does. These are also
    /// the screens a blocked user is stuck on, which is the worst place to
    /// trade legibility for material.
    private func fallbackStage<Actions: View>(
        struckThrough: Bool,
        title: String,
        message: String,
        @ViewBuilder actions: () -> Actions
    ) -> some View {
        VStack(spacing: 0) {
            OCRRadar(diameter: 66, sweeping: false, struckThrough: struckThrough)
                .padding(.bottom, 22)

            Text(title)
                .font(.ocrSectionHead())
                .tracking(-0.45)
                .foregroundStyle(Theme.textPrimary)
                .padding(.bottom, Theme.spacingS)

            Text(message)
                .font(.ocrBody())
                .foregroundStyle(Theme.textSecondary)
                .ocrBodyLeading(size: 14.5)
                .padding(.bottom, 26)

            VStack(spacing: Theme.spacingS) {
                actions()
            }
            .frame(maxWidth: 250)
        }
        .multilineTextAlignment(.center)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .padding(.horizontal, 32)
    }

    private func libraryPickerButton(title: String) -> some View {
        PhotosPicker(selection: $pickerItem, matching: .images) {
            Text(title)
        }
    }

    // MARK: - Actions

    private var isShowingError: Binding<Bool> {
        Binding(
            get: { errorMessage != nil },
            set: { if !$0 { errorMessage = nil } }
        )
    }

    private func capturePhoto() async {
        guard !isCapturing else { return }
        isCapturing = true
        defer { isCapturing = false }
        do {
            capturedImage = try await camera.capturePhoto()
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    private func loadPickedPhoto(_ item: PhotosPickerItem) async {
        defer { pickerItem = nil }
        do {
            guard
                let data = try await item.loadTransferable(type: Data.self),
                let uiImage = UIImage(data: data),
                let cgImage = ImageResizing.uprightCGImage(from: uiImage)
            else {
                errorMessage = "That photo could not be loaded. Try a different one."
                return
            }
            capturedImage = cgImage
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    private func analyze(_ image: CGImage) async {
        guard !isAnalyzing else { return }
        isAnalyzing = true
        defer { isAnalyzing = false }
        do {
            let result = try await classifier.classify(image)
            let thumbnail = ImageResizing.jpegThumbnail(from: image)
            if let record = ScanRecord(result: result, thumbnailData: thumbnail) {
                modelContext.insert(record)
                // Save immediately: a scan must survive even if the app is
                // killed before SwiftData's periodic autosave fires.
                try? modelContext.save()
            }
            presentedOutcome = AnalysisOutcome(result: result)
        } catch {
            errorMessage = error.localizedDescription
        }
    }
}

/// Wraps a finished classification in an identity so it can drive one
/// `sheet(item:)` presentation. `ResultView` deliberately never shows the
/// analyzed photo, so the image is not carried through.
private struct AnalysisOutcome: Identifiable {
    let id = UUID()
    let result: ClassificationResult
}

#Preview {
    let configuration = ModelConfiguration(isStoredInMemoryOnly: true)
    if let container = try? ModelContainer(for: ScanRecord.self, configurations: configuration) {
        ScanView()
            .modelContainer(container)
            .environment(\.lesionClassifier, MockLesionClassifier())
            .preferredColorScheme(.dark)
    }
}
