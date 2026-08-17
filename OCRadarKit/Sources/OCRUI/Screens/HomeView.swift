import OCRCore
import SwiftUI

/// Landing tab: branded hero, a three-step explainer, the model status card,
/// and the short medical disclaimer.
struct HomeView: View {
    @Environment(\.lesionClassifier) private var classifier

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: Theme.spacingL) {
                    heroCard
                    howItWorksCard
                    modelStatusCard
                    disclaimerCard
                }
                .padding()
            }
            .navigationTitle("OCRadar")
        }
    }

    private var heroCard: some View {
        GlassCard {
            VStack(spacing: Theme.spacingM) {
                ZStack(alignment: .bottomTrailing) {
                    ZStack {
                        Circle()
                            .fill(
                                LinearGradient(
                                    colors: [Theme.accent, Theme.accent.opacity(0.55)],
                                    startPoint: .topLeading,
                                    endPoint: .bottomTrailing
                                )
                            )
                        Image(systemName: "mouth.fill")
                            .font(.largeTitle)
                            .foregroundStyle(.white)
                    }
                    .frame(width: 96, height: 96)

                    Image(systemName: "camera.viewfinder")
                        .font(.title3)
                        .foregroundStyle(Theme.accent)
                        .padding(Theme.spacingXS)
                        .background(.thinMaterial, in: .circle)
                }
                .accessibilityHidden(true)

                Text("Oral lesion screening on your iPhone")
                    .font(.title3.bold())
                    .multilineTextAlignment(.center)

                Text("Photograph a spot in your mouth and get on-device guidance in seconds. Nothing you scan ever leaves your phone.")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
            }
            .frame(maxWidth: .infinity)
        }
    }

    private var howItWorksCard: some View {
        GlassCard {
            VStack(alignment: .leading, spacing: Theme.spacingM) {
                Text("How It Works")
                    .font(.headline)
                step(
                    number: 1,
                    systemImage: "camera.macro",
                    title: "Photograph",
                    detail: "Take a clear, well-lit photo of the area that concerns you."
                )
                step(
                    number: 2,
                    systemImage: "cpu",
                    title: "On-device analysis",
                    detail: "A local image model compares the photo against common oral lesion types."
                )
                step(
                    number: 3,
                    systemImage: "checkmark.seal",
                    title: "Guidance",
                    detail: "See risk-tiered guidance on whether to consult a dentist or physician."
                )
            }
        }
    }

    private func step(number: Int, systemImage: String, title: String, detail: String) -> some View {
        HStack(alignment: .top, spacing: Theme.spacingM) {
            Image(systemName: systemImage)
                .font(.title3)
                .foregroundStyle(Theme.accent)
                .frame(width: 28)
                .accessibilityHidden(true)
            VStack(alignment: .leading, spacing: Theme.spacingXS) {
                Text("\(number). \(title)")
                    .font(.subheadline.weight(.semibold))
                Text(detail)
                    .font(.footnote)
                    .foregroundStyle(.secondary)
            }
        }
    }

    private var modelStatusCard: some View {
        GlassCard {
            if classifier.kind == .mock {
                Label {
                    VStack(alignment: .leading, spacing: Theme.spacingXS) {
                        Text("Demo mode — no trained model installed")
                            .font(.subheadline.weight(.semibold))
                        Text("Results come from a deterministic stand-in so you can explore the app; they carry no medical meaning.")
                            .font(.footnote)
                            .foregroundStyle(.secondary)
                    }
                } icon: {
                    Image(systemName: "testtube.2")
                        .foregroundStyle(.orange)
                }
            } else {
                Label {
                    VStack(alignment: .leading, spacing: Theme.spacingXS) {
                        Text("Model \(classifier.manifest.modelVersion)")
                            .font(.subheadline.weight(.semibold))
                        Text("On-device Core ML model installed and ready.")
                            .font(.footnote)
                            .foregroundStyle(.secondary)
                    }
                } icon: {
                    Image(systemName: "checkmark.seal.fill")
                        .foregroundStyle(.green)
                }
            }
        }
    }

    private var disclaimerCard: some View {
        GlassCard {
            Label {
                Text(MedicalDisclaimer.short)
                    .font(.footnote)
                    .foregroundStyle(.secondary)
            } icon: {
                Image(systemName: "info.circle")
                    .foregroundStyle(Theme.accent)
            }
        }
    }
}

#Preview {
    HomeView()
        .environment(\.lesionClassifier, MockLesionClassifier())
}
