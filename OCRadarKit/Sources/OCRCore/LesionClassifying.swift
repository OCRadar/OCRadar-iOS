import CoreGraphics
import Foundation

public enum ClassifierKind: String, Sendable {
    /// Backed by a Core ML model bundled with the app.
    case coreML
    /// Deterministic stand-in used when no trained model is installed.
    case mock
}

/// A model that scores an oral photograph against the lesion classes declared
/// in its manifest.
public protocol LesionClassifying: Sendable {
    var kind: ClassifierKind { get }
    var manifest: ModelManifest { get }

    /// Runs inference on `image`. Implementations must be safe to call from
    /// any actor and should do their work off the main thread.
    func classify(_ image: CGImage) async throws -> ClassificationResult
}

public enum ClassifierError: LocalizedError, Equatable, Sendable {
    case modelNotInstalled
    case preprocessingFailed
    case inferenceFailed(String)
    case invalidManifest(String)

    public var errorDescription: String? {
        switch self {
        case .modelNotInstalled:
            "No trained model is installed in this build."
        case .preprocessingFailed:
            "The photo could not be prepared for analysis."
        case .inferenceFailed(let detail):
            "Analysis failed: \(detail)"
        case .invalidManifest(let detail):
            "The bundled model manifest is invalid: \(detail)"
        }
    }
}
