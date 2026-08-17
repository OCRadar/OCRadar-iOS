import CoreGraphics
import OCRCore
import SwiftUI
import UIKit

/// Presents one classification outcome: the analyzed image, the top class
/// with a probability ring and risk badge, every class score, and the full
/// medical disclaimer with professional-care guidance.
struct ResultView: View {
    let result: ClassificationResult
    let image: CGImage

    @Environment(\.lesionClassifier) private var classifier
    @Environment(\.dismiss) private var dismiss

    /// Ring diameter tracks Dynamic Type (its interior text is .title2), so
    /// the percent and "confidence" label stay inside the stroke at
    /// accessibility sizes instead of overflowing a fixed 132pt frame.
    @ScaledMetric(relativeTo: .title2) private var ringSize: CGFloat = 132

    var body: some View {
        NavigationStack {
            Group {
                if let top = result.top {
                    resultContent(for: top)
                } else {
                    ContentUnavailableView(
                        "No Result",
                        systemImage: "questionmark.circle",
                        description: Text("The analysis returned no scores. Try another photo.")
                    )
                }
            }
            .navigationTitle("Result")
            .toolbarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") {
                        dismiss()
                    }
                }
            }
        }
    }

    private func resultContent(for top: LabelScore) -> some View {
        ScrollView {
            VStack(spacing: Theme.spacingL) {
                if result.isDemoResult {
                    demoBanner
                }
                heroCard(for: top)
                allClassesCard
                footer(for: top)
            }
            .padding()
        }
    }

    /// Prominent notice shown whenever the result came from the demo
    /// stand-in classifier, so a mock score can never be mistaken for real
    /// analysis — regardless of how the user reached this screen.
    private var demoBanner: some View {
        Label {
            VStack(alignment: .leading, spacing: Theme.spacingXS) {
                Text("Demo result — no trained model installed")
                    .font(.subheadline.weight(.semibold))
                Text("These scores are generated placeholders and carry no medical meaning.")
                    .font(.footnote)
                    .foregroundStyle(.secondary)
            }
        } icon: {
            Image(systemName: "testtube.2")
                .foregroundStyle(.orange)
        }
        .padding(Theme.cardPadding)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(.orange.opacity(0.15), in: .rect(cornerRadius: Theme.cornerRadius))
        .overlay(
            RoundedRectangle(cornerRadius: Theme.cornerRadius)
                .strokeBorder(.orange.opacity(0.4), lineWidth: 1)
        )
        .accessibilityElement(children: .combine)
    }

    private func heroCard(for top: LabelScore) -> some View {
        GlassCard {
            VStack(spacing: Theme.spacingM) {
                Image(decorative: image, scale: 1)
                    .resizable()
                    .scaledToFill()
                    .frame(width: 120, height: 120)
                    .clipShape(.rect(cornerRadius: Theme.cornerRadius - Theme.spacingS))

                Text(top.displayName)
                    .font(.title2.bold())
                    .multilineTextAlignment(.center)

                ProbabilityRing(probability: top.probability, tint: top.riskLevel.color)
                    .frame(width: ringSize, height: ringSize)

                RiskBadge(level: top.riskLevel)

                // The per-class medical summary is withheld for demo results:
                // pairing genuine medical guidance with a fabricated score
                // would lend it unearned weight.
                if !result.isDemoResult,
                   let summary = classifier.manifest.classInfo(forID: top.id)?.summary {
                    Text(summary)
                        .font(.callout)
                        .foregroundStyle(.secondary)
                        .multilineTextAlignment(.center)
                }
            }
            .frame(maxWidth: .infinity)
        }
    }

    private var allClassesCard: some View {
        GlassCard {
            VStack(alignment: .leading, spacing: Theme.spacingM) {
                Text("All Classes")
                    .font(.headline)
                ForEach(result.scores) { score in
                    ScoreRow(score: score)
                }
            }
        }
    }

    private func footer(for top: LabelScore) -> some View {
        VStack(spacing: Theme.spacingM) {
            professionalCallout(for: top)
            GlassCard {
                Label {
                    Text(MedicalDisclaimer.full)
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                } icon: {
                    Image(systemName: "info.circle")
                        .foregroundStyle(Theme.accent)
                }
            }
        }
    }

    @ViewBuilder
    private func professionalCallout(for top: LabelScore) -> some View {
        // A demo score cannot "fall in a tier that warrants professional
        // evaluation" — only the generic when-in-doubt guidance applies.
        if top.riskLevel >= .moderate, !result.isDemoResult {
            calloutLabel(
                title: "See a dentist or physician",
                detail: "This result falls in a tier that warrants professional evaluation. Book an appointment soon rather than waiting.",
                tint: top.riskLevel.color
            )
            .padding(Theme.cardPadding)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(top.riskLevel.color.opacity(0.15), in: .rect(cornerRadius: Theme.cornerRadius))
            .overlay(
                RoundedRectangle(cornerRadius: Theme.cornerRadius)
                    .strokeBorder(top.riskLevel.color.opacity(0.4), lineWidth: 1)
            )
        } else {
            GlassCard {
                calloutLabel(
                    title: "When in doubt, see a dentist or physician",
                    detail: "Only a professional exam can rule a lesion in or out.",
                    tint: Theme.accent
                )
            }
        }
    }

    private func calloutLabel(title: String, detail: String, tint: Color) -> some View {
        Label {
            VStack(alignment: .leading, spacing: Theme.spacingXS) {
                Text(title)
                    .font(.headline)
                Text(detail)
                    .font(.footnote)
                    .foregroundStyle(.secondary)
            }
        } icon: {
            Image(systemName: "stethoscope")
                .foregroundStyle(tint)
        }
    }
}

/// Circular ring showing the top-class probability as a percentage.
private struct ProbabilityRing: View {
    let probability: Double
    let tint: Color

    var body: some View {
        ZStack {
            Circle()
                .stroke(tint.opacity(0.15), lineWidth: 12)
            Circle()
                .trim(from: 0, to: min(max(probability, 0), 1))
                .stroke(tint, style: StrokeStyle(lineWidth: 12, lineCap: .round))
                .rotationEffect(.degrees(-90))
            VStack(spacing: 0) {
                Text(percentText)
                    .font(.title2.bold())
                    .monospacedDigit()
                Text("confidence")
                    .font(.caption2)
                    .foregroundStyle(.secondary)
            }
        }
        .padding(Theme.spacingS)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("Confidence \(percentText)")
    }

    private var percentText: String {
        probability.formatted(.percent.precision(.fractionLength(0)))
    }
}

#Preview {
    let classes = ModelManifest.mockOralLesions.classes
    let probabilities: [Double] = [0.07, 0.06, 0.12, 0.52, 0.23]
    let scores = zip(classes, probabilities).map { info, probability in
        LabelScore(
            id: info.id,
            displayName: info.displayName,
            riskLevel: info.riskLevel,
            probability: probability
        )
    }
    let result = ClassificationResult(
        scores: scores,
        modelVersion: "mock-0.0.0",
        inferenceDuration: .milliseconds(180)
    )
    if let image = makeResultPreviewImage() {
        ResultView(result: result, image: image)
            .environment(\.lesionClassifier, MockLesionClassifier())
    }
}

/// Renders a flat-color stand-in photo for the preview above.
private func makeResultPreviewImage() -> CGImage? {
    let size = CGSize(width: 480, height: 360)
    let format = UIGraphicsImageRendererFormat()
    format.scale = 1
    let renderer = UIGraphicsImageRenderer(size: size, format: format)
    let rendered = renderer.image { context in
        UIColor.systemPink.withAlphaComponent(0.6).setFill()
        context.fill(CGRect(origin: .zero, size: size))
    }
    return rendered.cgImage
}
