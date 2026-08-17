import OCRCore
import SwiftUI

/// One row in an "All classes" list: display name, a linear probability bar
/// tinted by risk tier, and the probability as a percentage.
struct ScoreRow: View {
    let score: LabelScore

    var body: some View {
        VStack(alignment: .leading, spacing: Theme.spacingXS) {
            HStack(alignment: .firstTextBaseline) {
                Text(score.displayName)
                    .font(.subheadline)
                Spacer(minLength: Theme.spacingS)
                Text(percentText)
                    .font(.subheadline.weight(.semibold))
                    .monospacedDigit()
                    .foregroundStyle(.secondary)
            }
            probabilityBar
        }
        .accessibilityElement(children: .combine)
    }

    private var percentText: String {
        score.probability.formatted(.percent.precision(.fractionLength(0)))
    }

    private var probabilityBar: some View {
        GeometryReader { proxy in
            ZStack(alignment: .leading) {
                Capsule()
                    .fill(.quaternary)
                Capsule()
                    .fill(score.riskLevel.color)
                    .frame(width: max(4, proxy.size.width * score.probability))
            }
        }
        .frame(height: 6)
        .accessibilityHidden(true)
    }
}

#Preview {
    VStack(spacing: Theme.spacingM) {
        ScoreRow(score: LabelScore(
            id: "healthy",
            displayName: "No visible lesion",
            riskLevel: .low,
            probability: 0.62
        ))
        ScoreRow(score: LabelScore(
            id: "leukoplakia",
            displayName: "Leukoplakia",
            riskLevel: .moderate,
            probability: 0.27
        ))
        ScoreRow(score: LabelScore(
            id: "erythroplakia",
            displayName: "Erythroplakia",
            riskLevel: .high,
            probability: 0.11
        ))
    }
    .padding()
}
