import OCRCore
import SwiftUI

/// Design constants shared across every screen: the accent color, the single
/// card corner radius, spacing steps, and the risk-tier palette.
nonisolated enum Theme {
    /// App accent color, applied as the root tint.
    static let accent = Color.teal

    /// Corner radius of the one card treatment used app-wide.
    static let cornerRadius: CGFloat = 24

    /// Inner padding of `GlassCard`.
    static let cardPadding: CGFloat = 20

    static let spacingXS: CGFloat = 4
    static let spacingS: CGFloat = 8
    static let spacingM: CGFloat = 16
    static let spacingL: CGFloat = 24

    /// Color for a guidance tier: green for low, orange for moderate, red
    /// for high.
    static func color(for level: RiskLevel) -> Color {
        switch level {
        case .low: .green
        case .moderate: .orange
        case .high: .red
        }
    }
}

nonisolated extension RiskLevel {
    /// Theme color used wherever this tier appears in the UI.
    var color: Color { Theme.color(for: self) }

    /// Short human-readable label, e.g. "Low risk".
    var displayLabel: String {
        switch self {
        case .low: "Low risk"
        case .moderate: "Moderate risk"
        case .high: "High risk"
        }
    }
}
