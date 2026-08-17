import Foundation

/// Guidance tier attached to a lesion class. This is triage guidance for the
/// UI, not a diagnosis and not a measure of model certainty.
public enum RiskLevel: String, Codable, Sendable, CaseIterable, Comparable {
    case low
    case moderate
    case high

    public static func < (lhs: RiskLevel, rhs: RiskLevel) -> Bool {
        lhs.sortOrder < rhs.sortOrder
    }

    private var sortOrder: Int {
        switch self {
        case .low: 0
        case .moderate: 1
        case .high: 2
        }
    }
}
