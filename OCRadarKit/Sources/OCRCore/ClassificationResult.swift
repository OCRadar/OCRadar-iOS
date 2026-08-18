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
    /// The confidence floor the producing model declared, copied from its
    /// manifest at the moment of inference. `nil` when the model declares
    /// none — see `ModelManifest.abstainThreshold`.
    public let abstainThreshold: Double?

    /// The highest-scoring category, **whether or not it cleared the
    /// threshold**.
    ///
    /// This is the raw ranking and it stays available: the similarity ranking
    /// card shows every category with its score even in the abstaining case,
    /// because withholding the numbers as well as the name would leave a
    /// reader with no way to see how close the call was. What must not happen
    /// is a surface *naming* this category as the match — use ``confidentTop``
    /// for that.
    public var top: LabelScore? { scores.first }

    /// True when a threshold is in force and the closest category did not
    /// reach it.
    ///
    /// False when the model declares no threshold, which is what every v1
    /// manifest and the demo classifier do, so this is `false` for every
    /// result the app produced before the abstain path existed.
    public var isBelowAbstainThreshold: Bool {
        guard let abstainThreshold, let top else { return false }
        return top.probability < abstainThreshold
    }

    /// The closest category **when it may honestly be named as the match**,
    /// and `nil` otherwise.
    ///
    /// Every surface that puts a category name in front of a reader reads
    /// this rather than ``top``. The distinction is the whole abstain path: a
    /// result that fell below the floor still has a highest score, and
    /// presenting that score's name is exactly the behaviour the threshold was
    /// introduced to stop.
    public var confidentTop: LabelScore? {
        isBelowAbstainThreshold ? nil : top
    }

    /// True when this result came from the demo stand-in classifier rather
    /// than a trained model, and therefore carries no medical meaning.
    public var isDemoResult: Bool { ModelManifest.isDemoVersion(modelVersion) }

    public init(
        scores: [LabelScore],
        modelVersion: String,
        inferenceDuration: Duration,
        abstainThreshold: Double? = nil
    ) {
        self.scores = scores.sorted { $0.probability > $1.probability }
        self.modelVersion = modelVersion
        self.inferenceDuration = inferenceDuration
        self.abstainThreshold = abstainThreshold
    }
}
