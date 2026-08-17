import OCRCore
import SwiftData
import SwiftUI

extension EnvironmentValues {
    /// The classifier every screen runs inference through. `RootView`
    /// installs the app-provided instance; the mock default keeps previews
    /// and tests working without any wiring.
    @Entry var lesionClassifier: any LesionClassifying = MockLesionClassifier()

    /// The `ocrnew` app mark. The asset lives in the app target, not in
    /// `OCRadarKit`, so the app injects it through `RootView(classifier:logo:)`
    /// and it reaches Home and the disclaimer sheet from here. When it is
    /// `nil` — previews, tests, any host that does not pass one — call sites
    /// fall back to a `circle.circle` symbol in `Theme.accent`.
    @Entry var ocrLogo: Image? = nil

    /// Switches the selected tab from inside a screen: Home's settings button
    /// and "New scan"/"See all" actions, and History's empty-state button, all
    /// navigate across tabs. `RootView` owns `selectedTab`, so it publishes a
    /// setter rather than exposing the state.
    @Entry var selectTab = TabSelector { _ in }
}

/// The app's top-level tabs.
enum AppTab: String, Hashable {
    case home, scan, history, settings
}

extension View {
    /// What every full-screen scrolling tab needs from its scroll container so
    /// it meets the app's chrome correctly at both ends. The two edges are
    /// treated differently on purpose. See `OCRScrollEdges`.
    ///
    /// This replaces the earlier `ocrFlushTop()`, which hid the effect on
    /// `.all` edges and so suppressed the bottom one along with the top.
    func ocrScrollEdges() -> some View {
        modifier(OCRScrollEdges())
    }
}

/// The scroll-edge treatment shared by Home, History and Settings.
///
/// **Bottom — `.soft`, always.** The tab bar floats over the page instead of
/// reserving a safe-area inset, so without an edge effect the content ran out on
/// a hard cut behind it. `.soft` dissolves the last of the page under the
/// capsule. It softens the transition only: screens still pad their last element
/// clear of the bar by `Theme.tabBarClearance`, because the effect changes how
/// content *looks* under the bar, not whether it can be reached.
///
/// **Top — off at rest, on once scrolled.** Both halves of that are load
/// bearing, and shipping only the first half was a real defect.
///
/// *Off at rest,* because Home, History and Settings all open with a gradient
/// panel or band that runs to the physical top edge, and iOS 26's scroll edge
/// effect veils it: the sampled hero measured `#2F1C54` under the status bar
/// against `#4B2E8F` just below it, a 36% darkening of a colour
/// `design/README.md` pins exactly. The paired `ignoresSafeArea(edges: .top)` is
/// what lets the gradient start at that edge at all, so the design's 96pt top
/// inset is paid once rather than twice.
///
/// *On once scrolled,* because that same pair — no top safe-area inset and no
/// edge effect — leaves scrolled page content rendering straight under the clock
/// and the status icons with nothing between them. Parked at the foot of the
/// page (`-qaScrollBottom 1`, or just scrolling there) Settings put a row's
/// light label across "9:41" and the Wi-Fi and battery glyphs, and Home slid the
/// solid-white "New scan" capsule under white status-bar glyphs. Neither layer
/// was readable.
///
/// The switch is at the first point of scroll rather than at some panel-height
/// threshold, so there is no window in which content has reached the status bar
/// but the effect has not. The design's measurement is a measurement of the
/// screen *at rest*, and at rest — including after a scroll-to-top — the band
/// still renders at its exact stops.
///
/// The effect is the system's own and carries no animation of ours, so there is
/// nothing here to gate on Reduce Motion.
private struct OCRScrollEdges: ViewModifier {
    /// Whether the page has moved off its top. Rubber-band overscroll drives
    /// `contentOffset.y` negative, so a small positive threshold keeps this from
    /// flapping while the page bounces at rest.
    @State private var isScrolled = false

    func body(content: Content) -> some View {
        content
            .onScrollGeometryChange(for: Bool.self) { geometry in
                geometry.contentOffset.y > 1
            } action: { _, scrolled in
                isScrolled = scrolled
            }
            .ignoresSafeArea(edges: .top)
            .scrollEdgeEffectHidden(!isScrolled, for: .top)
            .scrollEdgeEffectStyle(.soft, for: .bottom)
    }
}

/// The tab-switching setter published through the environment, called as
/// `selectTab(.scan)`.
///
/// It wraps its closure in a type rather than being stored as a bare closure so
/// the environment value stays comparable: SwiftUI cannot compare closures, so
/// a raw one would invalidate every screen reading the key on each `RootView`
/// update. `RootView` re-creates the same semantic setter every time, so all
/// instances are equal by construction.
///
/// Isolation is explicit because `OCRUI` compiles with
/// `defaultIsolation(MainActor)`: the type itself has to be `nonisolated` for
/// the `Equatable` witness, while the stored closure — written in this module,
/// and assigning to `@State` — is main-actor-isolated.
nonisolated struct TabSelector: Equatable {
    private let select: @MainActor (AppTab) -> Void

    init(_ select: @escaping @MainActor (AppTab) -> Void) {
        self.select = select
    }

    @MainActor
    func callAsFunction(_ tab: AppTab) {
        select(tab)
    }

    static func == (lhs: TabSelector, rhs: TabSelector) -> Bool { true }
}

/// The app's top-level view: a four-tab layout over Home, Scan, History, and
/// Settings, gated by a one-time acknowledgement of the medical disclaimer.
///
/// The system tab bar is not used. The design calls for a floating capsule bar
/// that content scrolls *under*, so the tabs are switched here and `OCRTabBar`
/// is overlaid on a bottom-aligned `ZStack`; screens add their own bottom
/// padding to clear it. Only the selected screen is built, which keeps the
/// camera session tied to the Scan tab's lifetime.
public struct RootView: View {
    private let classifier: any LesionClassifying
    private let logo: Image?

    @AppStorage("hasAcknowledgedDisclaimer") private var hasAcknowledgedDisclaimer = false
    @State private var selectedTab: AppTab

    /// Creates the root view.
    /// - Parameters:
    ///   - classifier: The inference backend used across the app —
    ///     a Core ML model when one is bundled, otherwise the deterministic
    ///     mock so the UI stays fully navigable in demo mode.
    ///   - logo: The `ocrnew` app mark, injected by the app target because the
    ///     asset catalog lives there rather than in the package. Defaults to
    ///     `nil`, which falls back to an SF Symbol.
    public init(classifier: any LesionClassifying, logo: Image? = nil) {
        self.classifier = classifier
        self.logo = logo
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
        ZStack(alignment: .bottom) {
            // The root plane, and the reason nothing anywhere in the app can
            // fall through to a bare rectangle: every screen paints its own
            // ambient background, and this one covers the seams between them —
            // behind a rising sheet, behind a tab swap, behind the rubber band
            // at the end of a scroll. It is the same treatment, so those seams
            // are invisible rather than a shade off.
            OCRAmbientBackground()
            selectedScreen
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            OCRTabBar(selection: $selectedTab)
        }
        .tint(Theme.accent)
        // The QA hook is applied inside the `.environment` write below so its
        // `@Environment(\.lesionClassifier)` (and the ResultView it presents)
        // resolve to the app-installed classifier, not the `@Entry` default.
        #if DEBUG
        .modifier(QAAutomationHooks())
        #endif
        .environment(\.lesionClassifier, classifier)
        .environment(\.ocrLogo, logo)
        .environment(\.selectTab, TabSelector { tab in selectedTab = tab })
        .preferredColorScheme(.dark)
        .sheet(isPresented: needsAcknowledgement) {
            // The first-launch gate: "I understand" is what sets
            // `hasAcknowledgedDisclaimer`, and the sheet cannot be dismissed
            // any other way.
            MedicalDisclaimerSheet(
                title: "Before you begin",
                actionTitle: "I understand",
                onAction: { hasAcknowledgedDisclaimer = true }
            )
            // Re-stated for the sheet's own environment. The gate is presented
            // from `RootView` itself, and the `ocrLogo` written into the body's
            // environment above did not reach it — the first-launch sheet was
            // drawing the `circle.circle` fallback while Home, one layer down,
            // drew the real mark.
            .environment(\.ocrLogo, logo)
            .interactiveDismissDisabled()
            .medicalDisclaimerPresentation()
        }
    }

    @ViewBuilder
    private var selectedScreen: some View {
        switch selectedTab {
        case .home: HomeView()
        case .scan: ScanView()
        case .history: HistoryView()
        case .settings: SettingsView()
        }
    }

    private var needsAcknowledgement: Binding<Bool> {
        Binding(
            get: { !hasAcknowledgedDisclaimer },
            set: { hasAcknowledgedDisclaimer = !$0 }
        )
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
    }

    @Environment(\.lesionClassifier) private var classifier
    @Environment(\.modelContext) private var modelContext
    @State private var qaOutcome: QAOutcome?
    @State private var qaDetailRecord: ScanRecord?

    func body(content: Content) -> some View {
        content
            .task {
                guard let sample = QASampleImage.gradient() else { return }
                if UserDefaults.standard.bool(forKey: "qaSeedHistory") {
                    seedHistory(with: sample)
                }
                if UserDefaults.standard.bool(forKey: "qaShowResult"),
                   let result = try? await classifier.classify(sample) {
                    qaOutcome = QAOutcome(result: result)
                }
                // `-qaShowDetail 1` opens the newest record's detail sheet.
                // It is otherwise only reachable by tapping a row, which a
                // headless screenshot sweep cannot do.
                if UserDefaults.standard.bool(forKey: "qaShowDetail") {
                    var descriptor = FetchDescriptor<ScanRecord>(
                        sortBy: [SortDescriptor(\.timestamp, order: .reverse)]
                    )
                    descriptor.fetchLimit = 1
                    qaDetailRecord = try? modelContext.fetch(descriptor).first
                }
            }
            .sheet(item: $qaOutcome) { outcome in
                ResultView(result: outcome.result)
            }
            .sheet(item: $qaDetailRecord) { record in
                HistoryDetailView(record: record)
                    .presentationCornerRadius(Theme.sheetCorner)
                    .presentationBackground(Theme.canvas)
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
}
#endif

#Preview("Root") {
    let configuration = ModelConfiguration(isStoredInMemoryOnly: true)
    if let container = try? ModelContainer(for: ScanRecord.self, configurations: configuration) {
        RootView(classifier: MockLesionClassifier())
            .modelContainer(container)
    }
}

#Preview("Disclaimer") {
    OCRAmbientBackground()
        .sheet(isPresented: .constant(true)) {
            MedicalDisclaimerSheet(
                title: "Before you begin",
                actionTitle: "I understand",
                onAction: {}
            )
            .medicalDisclaimerPresentation()
        }
        .environment(\.lesionClassifier, MockLesionClassifier())
}
