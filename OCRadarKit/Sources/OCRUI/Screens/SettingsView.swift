import OCRCore
import SwiftUI

/// Settings tab: model details, privacy statement, support contact, app
/// info, and the full medical disclaimer.
struct SettingsView: View {
    @Environment(\.lesionClassifier) private var classifier

    var body: some View {
        NavigationStack {
            List {
                modelSection
                privacySection
                supportSection
                aboutSection
                disclaimerSection
            }
            .navigationTitle("Settings")
        }
    }

    private var modelSection: some View {
        Section("Model") {
            LabeledContent("Engine", value: classifier.kind == .mock ? "Demo (mock)" : "Core ML")
            LabeledContent("Version", value: classifier.manifest.modelVersion)
            ForEach(classifier.manifest.classes) { classInfo in
                HStack(alignment: .firstTextBaseline) {
                    Text(classInfo.displayName)
                    Spacer(minLength: Theme.spacingS)
                    RiskBadge(level: classInfo.riskLevel)
                }
            }
        }
    }

    private var privacySection: some View {
        Section("Privacy") {
            Label {
                Text("All analysis happens on this device. Photos and results never leave your iPhone unless you share them.")
            } icon: {
                Image(systemName: "lock.shield")
                    .foregroundStyle(Theme.accent)
            }
        }
    }

    private var supportSection: some View {
        Section("Support") {
            if let url = URL(string: "mailto:contact@ocradar.com") {
                Link(destination: url) {
                    Label("Contact Support", systemImage: "envelope")
                }
            }
        }
    }

    private var aboutSection: some View {
        Section("About") {
            LabeledContent("Version", value: appVersion)
            LabeledContent("Copyright", value: "© 2026 OCRadar")
        }
    }

    private var disclaimerSection: some View {
        Section("Disclaimer") {
            Text(MedicalDisclaimer.full)
                .font(.footnote)
                .foregroundStyle(.secondary)
        }
    }

    private var appVersion: String {
        let info = Bundle.main.infoDictionary
        let version = info?["CFBundleShortVersionString"] as? String ?? "1.0"
        if let build = info?["CFBundleVersion"] as? String {
            return "\(version) (\(build))"
        }
        return version
    }
}

#Preview {
    SettingsView()
        .environment(\.lesionClassifier, MockLesionClassifier())
}
