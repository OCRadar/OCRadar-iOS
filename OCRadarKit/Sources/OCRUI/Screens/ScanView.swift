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
struct ScanView: View {
    @Environment(\.lesionClassifier) private var classifier
    @Environment(\.modelContext) private var modelContext
    @Environment(\.openURL) private var openURL

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

    /// Gap between the top of the stage and the top of the radar's box: the
    /// spec centres the radar at y 206 in stage coordinates, and the radar box
    /// is 250 tall.
    private let radarBoxTop: CGFloat = 81

    var body: some View {
        ZStack {
            Theme.canvas
                .ignoresSafeArea()

            VStack(spacing: 16) {
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
        .task { await camera.start() }
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
            RoundedRectangle(cornerRadius: Theme.stageCorner)
                .strokeBorder(Theme.stageBorder, lineWidth: 1)
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

                if !forcesLiveStage, camera.state == .idle || camera.state == .configuring {
                    ProgressView()
                        .controlSize(.large)
                        .tint(Theme.accent)
                }

                VStack(spacing: 0) {
                    // Absorbs first so the framing aid keeps its 81pt offset on
                    // a tall stage and compresses on a short one.
                    Spacer(minLength: 0)
                        .frame(maxHeight: radarBoxTop)

                    framingAid(diameter: radarDiameter(inStageHeight: proxy.size.height))

                    Text("Frame the area that concerns you\nHold steady in good light")
                        .font(.system(size: 14))
                        .foregroundStyle(Theme.textSecondary)
                        .multilineTextAlignment(.center)
                        .lineSpacing(3)
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

    /// Radar and reticle share one `ZStack`, so their centres coincide — the
    /// spec calls this out twice, and the reticle keeps its ratio to the radar
    /// when the radar is scaled down for a short stage.
    private func framingAid(diameter: CGFloat) -> some View {
        ZStack {
            OCRRadar(diameter: diameter, sweeping: true)
                .opacity(0.55)

            OCRReticle()
                .frame(height: diameter * Self.reticleRatio)
                .padding(.horizontal, 40)
        }
        .frame(maxWidth: .infinity)
        .frame(height: diameter)
        .accessibilityHidden(true)
    }

    private var captureControls: some View {
        HStack(spacing: 40) {
            libraryCircleButton

            shutterButton

            // Balances the library button so the shutter stays optically
            // centred in the stage.
            Color.clear
                .frame(width: 48, height: 48)
                .accessibilityHidden(true)
        }
        .frame(maxWidth: .infinity)
    }

    private var libraryCircleButton: some View {
        PhotosPicker(selection: $pickerItem, matching: .images) {
            Image(systemName: "photo.on.rectangle")
                .font(.system(size: 21))
                .foregroundStyle(Theme.numeralMuted)
                .frame(width: 48, height: 48)
                .background(.white.opacity(0.08), in: .circle)
        }
        .buttonStyle(.plain)
        .accessibilityLabel("Choose a photo from your library")
    }

    private var shutterButton: some View {
        Button {
            Task { await capturePhoto() }
        } label: {
            ZStack {
                Circle()
                    .fill(Theme.accent.opacity(0.12))
                Circle()
                    .strokeBorder(Theme.accent.opacity(0.55), lineWidth: 2)
                Theme.button
                    .clipShape(.circle)
                    .frame(width: 60, height: 60)
            }
            .frame(width: 78, height: 78)
        }
        .buttonStyle(.plain)
        .disabled(camera.state != .running || isCapturing)
        .accessibilityLabel("Capture photo")
    }

    /// Top-left capsule: a white-8% pill with a pulsing dot and one short line.
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
        .background(.white.opacity(0.08), in: .capsule)
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
                    analyzingCapsule
                } else {
                    reviewActions(for: image)
                }
            }
            .padding(.horizontal, Theme.stageInset)
            .padding(.bottom, 22)

            statusPill(text: "Review", dot: Theme.accent)
        }
    }

    private var analyzingCapsule: some View {
        HStack(spacing: 11) {
            OCRStatusDot(color: Theme.accent, pulsing: true)
            Text("Analyzing on device…")
                .font(.system(size: 16, weight: .semibold))
                .foregroundStyle(Theme.textPrimary)
        }
        .frame(maxWidth: .infinity, minHeight: actionHeight)
        .background(Theme.accent.opacity(0.16), in: .capsule)
        .accessibilityElement(children: .combine)
        .accessibilityLabel("Analyzing on device")
    }

    /// "Retake" and "Analyze" split the row 1 : 1.4, per the spec.
    private func reviewActions(for image: CGImage) -> some View {
        GeometryReader { proxy in
            let gap = Theme.spacingS
            let retakeWidth = max(88, (proxy.size.width - gap) / 2.4)

            HStack(spacing: gap) {
                Button("Retake") {
                    capturedImage = nil
                }
                .buttonStyle(OCRSecondaryButtonStyle())
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
            .buttonStyle(OCRPrimaryButtonStyle(height: 50))

            libraryPickerButton(title: "Choose Photo")
                .buttonStyle(OCRSecondaryButtonStyle())
        }
    }

    private var unavailableStage: some View {
        fallbackStage(
            struckThrough: false,
            title: "Camera unavailable",
            message: "No camera is available on this device. Choose a photo from your library to analyze instead."
        ) {
            libraryPickerButton(title: "Choose Photo")
                .buttonStyle(OCRPrimaryButtonStyle(height: 50))
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
            .buttonStyle(OCRPrimaryButtonStyle(height: 50))
        }
    }

    /// Shared blocked-camera layout: a small static radar glyph, a title, an
    /// explanation, and one or two capsule actions — centred in the stage.
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
                .lineSpacing(3)
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
