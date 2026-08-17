import CoreGraphics
import OCRCapture
import OCRCore
import PhotosUI
import SwiftData
import SwiftUI
import UIKit

/// Capture tab: live camera preview with a glass shutter, photo-library
/// import, a capture-review step, and on-device analysis that saves each
/// result to History.
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

    var body: some View {
        NavigationStack {
            content
                .navigationTitle("Scan")
                .toolbarTitleDisplayMode(.inline)
        }
        .task { await camera.start() }
        .onDisappear { camera.stop() }
        .onChange(of: pickerItem) { _, item in
            guard let item else { return }
            Task { await loadPickedPhoto(item) }
        }
        .sheet(item: $presentedOutcome, onDismiss: { capturedImage = nil }) { outcome in
            ResultView(result: outcome.result, image: outcome.image)
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

    // MARK: - Layers

    @ViewBuilder
    private var content: some View {
        if let capturedImage {
            reviewLayer(for: capturedImage)
        } else {
            switch camera.state {
            case .idle, .configuring, .running:
                cameraLayer
            case .denied:
                deniedLayer
            case .unavailable:
                libraryOnlyLayer
            case .failed(let message):
                failedLayer(message)
            }
        }
    }

    private var cameraLayer: some View {
        ZStack {
            CameraPreview(service: camera)
                .ignoresSafeArea()

            if camera.state == .idle || camera.state == .configuring {
                ProgressView()
                    .controlSize(.large)
            }

            VStack {
                Spacer()
                captureControls
            }
        }
    }

    private var captureControls: some View {
        HStack {
            PhotosPicker(selection: $pickerItem, matching: .images) {
                Image(systemName: "photo.on.rectangle")
                    .font(.title2)
                    .padding(Theme.spacingM)
            }
            .glassEffect(.regular, in: .circle)
            .accessibilityLabel("Choose a photo from your library")

            Spacer()

            shutterButton

            Spacer()

            // Balances the picker so the shutter stays centered.
            Color.clear
                .frame(width: 56, height: 56)
                .accessibilityHidden(true)
        }
        .padding(.horizontal, Theme.spacingL)
        .padding(.bottom, Theme.spacingM)
    }

    private var shutterButton: some View {
        Button {
            Task { await capturePhoto() }
        } label: {
            ZStack {
                Circle()
                    .strokeBorder(.white.opacity(0.9), lineWidth: 4)
                    .frame(width: 72, height: 72)
                Circle()
                    .fill(.white)
                    .frame(width: 56, height: 56)
            }
            .padding(Theme.spacingXS)
        }
        .buttonStyle(.plain)
        .glassEffect(.regular, in: .circle)
        .disabled(camera.state != .running || isCapturing)
        .accessibilityLabel("Capture photo")
    }

    private func reviewLayer(for image: CGImage) -> some View {
        ZStack {
            Color.black
                .ignoresSafeArea()

            Image(decorative: image, scale: 1)
                .resizable()
                .scaledToFit()

            VStack {
                Spacer()
                if isAnalyzing {
                    ProgressView("Analyzing…")
                        .padding(Theme.spacingM)
                        .glassEffect(.regular, in: .rect(cornerRadius: Theme.cornerRadius))
                        .padding(.bottom, Theme.spacingL)
                } else {
                    HStack(spacing: Theme.spacingM) {
                        Button("Retake") {
                            capturedImage = nil
                        }
                        .buttonStyle(.glass)

                        Button("Analyze") {
                            Task { await analyze(image) }
                        }
                        .buttonStyle(.glassProminent)
                    }
                    .controlSize(.large)
                    .padding(.bottom, Theme.spacingL)
                }
            }
        }
    }

    private var deniedLayer: some View {
        ContentUnavailableView {
            Label("Camera Access Needed", systemImage: "lock.shield")
        } description: {
            Text("OCRadar uses the camera to photograph areas inside your mouth. Allow camera access in Settings to scan, or analyze a photo from your library instead.")
        } actions: {
            Button("Open Settings") {
                if let url = URL(string: UIApplication.openSettingsURLString) {
                    openURL(url)
                }
            }
            .buttonStyle(.glassProminent)

            libraryPickerButton(title: "Choose Photo")
                .buttonStyle(.glass)
        }
    }

    private var libraryOnlyLayer: some View {
        ContentUnavailableView {
            Label("Camera Unavailable", systemImage: "photo.on.rectangle")
        } description: {
            Text("No camera is available on this device. Choose a photo from your library to analyze instead.")
        } actions: {
            libraryPickerButton(title: "Choose Photo")
                .buttonStyle(.glassProminent)
        }
    }

    private func failedLayer(_ message: String) -> some View {
        ContentUnavailableView {
            Label("Camera Error", systemImage: "exclamationmark.triangle")
        } description: {
            Text(message)
        } actions: {
            Button("Try Again") {
                Task { await camera.start() }
            }
            .buttonStyle(.glassProminent)
        }
    }

    private func libraryPickerButton(title: String) -> some View {
        PhotosPicker(selection: $pickerItem, matching: .images) {
            Label(title, systemImage: "photo")
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
            }
            presentedOutcome = AnalysisOutcome(result: result, image: image)
        } catch {
            errorMessage = error.localizedDescription
        }
    }
}

/// Pairs a finished classification with the image it ran on so both can be
/// handed to `ResultView` through one `sheet(item:)` presentation.
private struct AnalysisOutcome: Identifiable {
    let id = UUID()
    let result: ClassificationResult
    let image: CGImage
}

#Preview {
    let configuration = ModelConfiguration(isStoredInMemoryOnly: true)
    if let container = try? ModelContainer(for: ScanRecord.self, configurations: configuration) {
        ScanView()
            .modelContainer(container)
            .environment(\.lesionClassifier, MockLesionClassifier())
    }
}
