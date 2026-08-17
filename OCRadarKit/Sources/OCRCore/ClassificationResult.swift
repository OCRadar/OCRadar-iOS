import Foundation

/// Probability assigned to a single lesion class, denormalized with its
/// display metadata so the UI never has to re-join against the manifest.
public struct LabelScore: Sendable, Equatable, Identifiable {
    public let id: String
    public let displayName: String
    public let riskLevel: RiskLevel
    /// Softmax probability in `0...1`.
    public let probability: Double

    public init(id: String, displayName: String, riskLevel: RiskLevel, probability: Double) {
        self.id = id
        self.displayName = displayName
        self.riskLevel = riskLevel
        self.probability = probability
    }
}

/// The outcome of one inference pass. Scores are always sorted
/// most-probable first.
public struct ClassificationResult: Sendable, Equatable {
    public let scores: [LabelScore]
    public let modelVersion: String
    public let inferenceDuration: Duration

    public var top: LabelScore? { scores.first }

    public init(scores: [LabelScore], modelVersion: String, inferenceDuration: Duration) {
        self.scores = scores.sorted { $0.probability > $1.probability }
        self.modelVersion = modelVersion
        self.inferenceDuration = inferenceDuration
    }
}
