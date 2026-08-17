import OCRCore
import SwiftData
import SwiftUI

extension EnvironmentValues {
    /// The classifier every screen runs inference through. `RootView`
    /// installs the app-provided instance; the mock default keeps previews
    /// and tests working without any wiring.
    @Entry var lesionClassifier: any LesionClassifying = MockLesionClassifier()
}

/// The app's top-level view: a four-tab layout over Home, Scan, History, and
/// Settings, gated by a one-time acknowledgement of the medical disclaimer.
public struct RootView: View {
    private let classifier: any LesionClassifying

    @AppStorage("hasAcknowledgedDisclaimer") private var hasAcknowledgedDisclaimer = false

    /// Creates the root view.
    /// - Parameter classifier: The inference backend used across the app —
    ///   a Core ML model when one is bundled, otherwise the deterministic
    ///   mock so the UI stays fully navigable in demo mode.
    public init(classifier: any LesionClassifying) {
        self.classifier = classifier
    }

    public var body: some View {
        TabView {
            Tab("Home", systemImage: "house") {
                HomeView()
            }
            Tab("Scan", systemImage: "camera.viewfinder") {
                ScanView()
            }
            Tab("History", systemImage: "clock.arrow.circlepath") {
                HistoryView()
            }
            Tab("Settings", systemImage: "gearshape") {
                SettingsView()
            }
        }
        .tint(Theme.accent)
        .environment(\.lesionClassifier, classifier)
        .sheet(isPresented: needsAcknowledgement) {
            DisclaimerSheet {
                hasAcknowledgedDisclaimer = true
            }
            .interactiveDismissDisabled()
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

#Preview {
    let configuration = ModelConfiguration(isStoredInMemoryOnly: true)
    if let container = try? ModelContainer(for: ScanRecord.self, configurations: configuration) {
        RootView(classifier: MockLesionClassifier())
            .modelContainer(container)
    }
}
