import OCRCore
import SwiftUI

/// Capsule badge for a guidance tier: green for low, orange for moderate,
/// red for high.
struct RiskBadge: View {
    let level: RiskLevel

    var body: some View {
        Text(level.displayLabel)
            .font(.caption.weight(.semibold))
            .foregroundStyle(level.color)
            .padding(.horizontal, Theme.spacingS + Theme.spacingXS)
            .padding(.vertical, Theme.spacingXS)
            .background(level.color.opacity(0.18), in: .capsule)
    }
}

/// Capsule badge marking a result or saved scan that came from the demo
/// stand-in classifier and therefore carries no medical meaning.
struct DemoBadge: View {
    var body: some View {
        Text("Demo")
            .font(.caption.weight(.semibold))
            .foregroundStyle(.orange)
            .padding(.horizontal, Theme.spacingS + Theme.spacingXS)
            .padding(.vertical, Theme.spacingXS)
            .background(.orange.opacity(0.18), in: .capsule)
            .accessibilityLabel("Demo result")
    }
}

#Preview {
    VStack(spacing: Theme.spacingS) {
        ForEach(RiskLevel.allCases, id: \.self) { level in
            RiskBadge(level: level)
        }
        DemoBadge()
    }
    .padding()
}
