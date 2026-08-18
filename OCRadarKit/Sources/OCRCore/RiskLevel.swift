import Foundation

/// Next-step guidance tier attached to a reference category.
///
/// This is guidance about **what to do**, not a statement about how sick
/// anyone is. It is not a diagnosis, not a severity assessment, and not a
/// measure of model certainty. The user-facing wording lives in
/// `RiskLevel.displayLabel` (OCRUI) and is phrased as an action for exactly
/// that reason — see the note there before changing it.
///
/// The case names and raw values are frozen. They are persisted in
/// `ScanRecord`, they are part of the `ModelManifest` JSON schema, and the
/// `ml/` pipeline emits them; renaming one would break every saved scan and
/// every exported model. Reframing happens in the label, never here.
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
