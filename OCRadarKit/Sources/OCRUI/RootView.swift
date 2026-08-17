import OCRCore
import SwiftData
import SwiftUI

extension EnvironmentValues {
    /// The classifier every screen runs inference through. `RootView`
    /// installs the app-provided instance; the mock default keeps previews
    /// and tests working without any wiring.
    @Entry var lesionClassifier: any LesionClassifying = MockLesionClassifier()
}

/// The app's top-level tabs.
enum AppTab: String, Hashable {
    case home, scan, history, settings
}

/// The app's top-level view: a four-tab layout over Home, Scan, History, and
/// Settings, gated by a one-time acknowledgement of the medical disclaimer.
public struct RootView: View {
    private let classifier: any LesionClassifying

    @AppStorage("hasAcknowledgedDisclaimer") private var hasAcknowledgedDisclaimer = false
    @State private var selectedTab: AppTab

    /// Creates the root view.
    /// - Parameter classifier: The inference backend used across the app —
    ///   a Core ML model when one is bundled, otherwise the deterministic
    ///   mock so the UI stays fully navigable in demo mode.
    public init(classifier: any LesionClassifying) {
        self.classifier = classifier
        var initialTab = AppTab.home
        #if DEBUG
        // QA-automation hook (debug builds only): `-qaTab scan` selects a
        // tab at launch so headless screenshot sweeps can reach every screen.
        let defaults = UserDefaults.standard
        if let raw = defaults.string(forKey: "qaTab"),
           let tab = AppTab(rawValue: raw) {
            initialTab = tab
        }
        // Any qa* argument pre-acknowledges the medical disclaimer: on a
        // fresh container the blocking first-launch sheet would otherwise
        // occupy the only presentation slot (dropping `-qaShowResult`'s
        // ResultView) or be what `-qaTab` screenshots instead of the tab.
        if defaults.string(forKey: "qaTab") != nil
            || defaults.bool(forKey: "qaSeedHistory")
            || defaults.bool(forKey: "qaShowResult") {
            defaults.set(true, forKey: "hasAcknowledgedDisclaimer")
        }
        #endif
        _selectedTab = State(initialValue: initialTab)
    }

    public var body: some View {
        TabView(selection: $selectedTab) {
            Tab("Home", systemImage: "house", value: .home) {
                HomeView()
            }
            Tab("Scan", systemImage: "camera.viewfinder", value: .scan) {
                ScanView()
            }
            Tab("History", systemImage: "clock.arrow.circlepath", value: .history) {
                HistoryView()
            }
            Tab("Settings", systemImage: "gearshape", value: .settings) {
                SettingsView()
            }
        }
        .tint(Theme.accent)
        // The QA hook is applied inside the `.environment` write below so its
        // `@Environment(\.lesionClassifier)` (and the ResultView it presents)
        // resolve to the app-installed classifier, not the `@Entry` default.
        #if DEBUG
        .modifier(QAAutomationHooks())
        #endif
        .environment(\.lesionClassifier, classifier)
        .sheet(isPresented: needsAcknowledgement) {
            DisclaimerSheet {
                hasAcknowledgedDisclaimer = true
            }
            .interactiveDismissDisabled()
            .presentationDetents([.medium, .large])
        }
    }

    private var needsAcknowledgement: Binding<Bool> {
        Binding(
            get: { !hasAcknowledgedDisclaimer },
            set: { hasAcknowledgedDisclaimer = !$0 }
        )
    }
}

/// First-launch sheet that requires the user to acknowledge the
/// screening-aid disclaimer before using the app.
private struct DisclaimerSheet: View {
    let onAcknowledge: () -> Void

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: Theme.spacingL) {
                    Image(systemName: "stethoscope")
                        .font(.largeTitle)
                        .foregroundStyle(Theme.accent)
                        .accessibilityHidden(true)
                    Text("A screening aid, not a diagnosis")
                        .font(.title2.bold())
                    Text(MedicalDisclaimer.full)
                        .font(.body)
                        .foregroundStyle(.secondary)
                }
                .padding()
                .frame(maxWidth: .infinity, alignment: .leading)
            }
            .navigationTitle("Before You Begin")
            .toolbarTitleDisplayMode(.inline)
            .safeAreaInset(edge: .bottom) {
                Button {
                    onAcknowledge()
                } label: {
                    Text("I Understand")
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(.glassProminent)
                .controlSize(.large)
                .padding()
            }
        }
    }
}

#if DEBUG
/// Debug-build-only hooks that let headless QA automation reach states that
/// normally require touch interaction. Activated via launch arguments
/// (`-qaShowResult 1`, `-qaSeedHistory 1`), which Foundation parses into
/// `UserDefaults`. Compiled out of Release entirely. Any qa* argument also
/// pre-acknowledges the first-launch disclaimer (see `RootView.init`), so
/// these flows work on fresh containers without extra arguments.
private struct QAAutomationHooks: ViewModifier {
    private struct QAOutcome: Identifiable {
        let id = UUID()
        let result: ClassificationResult
        let image: CGImage
    }

    @Environment(\.lesionClassifier) private var classifier
    @Environment(\.modelContext) private var modelContext
    @State private var qaOutcome: QAOutcome?

    func body(content: Content) -> some View {
        content
            .task {
                guard let sample = Self.sampleImage() else { return }
                if UserDefaults.standard.bool(forKey: "qaSeedHistory") {
                    seedHistory(with: sample)
                }
                if UserDefaults.standard.bool(forKey: "qaShowResult"),
                   let result = try? await classifier.classify(sample) {
                    qaOutcome = QAOutcome(result: result, image: sample)
                }
            }
            .sheet(item: $qaOutcome) { outcome in
                ResultView(result: outcome.result, image: outcome.image)
            }
    }

    private func seedHistory(with image: CGImage) {
        // Bail out when the count cannot be determined — defaulting to 0 on
        // error would invert the idempotency guard and append duplicates.
        guard let existing = try? modelContext.fetchCount(FetchDescriptor<ScanRecord>()),
              existing == 0 else { return }
        let thumbnail = ImageResizing.jpegThumbnail(from: image)
        let seeds: [(String, String, RiskLevel, Double, Date)] = [
            ("healthy", "No visible lesion", .low, 0.91, .now.addingTimeInterval(-3_600)),
            ("leukoplakia", "Leukoplakia", .moderate, 0.64, .now.addingTimeInterval(-90_000)),
            ("erythroplakia", "Erythroplakia", .high, 0.55, .now.addingTimeInterval(-400_000)),
        ]
        for (id, name, risk, probability, timestamp) in seeds {
            modelContext.insert(
                ScanRecord(
                    timestamp: timestamp,
                    topClassID: id,
                    topClassName: name,
                    riskLevel: risk,
                    probability: probability,
                    modelVersion: "mock-0.0.0",
                    thumbnailData: id == "healthy" ? nil : thumbnail
                )
            )
        }
        try? modelContext.save()
    }

    /// A deterministic gradient bitmap standing in for a photograph.
    private static func sampleImage() -> CGImage? {
        let side = 640
        guard let context = CGContext(
            data: nil,
            width: side,
            height: side,
            bitsPerComponent: 8,
            bytesPerRow: 0,
            space: CGColorSpace(name: CGColorSpace.sRGB) ?? CGColorSpaceCreateDeviceRGB(),
            bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue
        ) else { return nil }
        let colors = [
            CGColor(red: 0.85, green: 0.45, blue: 0.40, alpha: 1),
            CGColor(red: 0.55, green: 0.20, blue: 0.25, alpha: 1),
        ] as CFArray
        if let gradient = CGGradient(colorsSpace: nil, colors: colors, locations: [0, 1]) {
            context.drawLinearGradient(
                gradient,
                start: .zero,
                end: CGPoint(x: side, y: side),
                options: []
            )
        }
        return context.makeImage()
    }
}
#endif

#Preview {
    let configuration = ModelConfiguration(isStoredInMemoryOnly: true)
    if let container = try? ModelContainer(for: ScanRecord.self, configurations: configuration) {
        RootView(classifier: MockLesionClassifier())
            .modelContainer(container)
    }
}
