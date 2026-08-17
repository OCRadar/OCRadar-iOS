import Foundation

/// Metadata that ships alongside a trained model. The training pipeline in
/// `ml/` emits this as `ModelManifest.json`; the app decodes it to drive the
/// result UI. The class `id`s must match the class labels embedded in the
/// Core ML model exactly.
public struct ModelManifest: Codable, Sendable, Equatable {
    public struct ClassInfo: Codable, Sendable, Equatable, Identifiable {
        /// Stable identifier; matches the class label embedded in the model.
        public let id: String
        public let displayName: String
        public let riskLevel: RiskLevel
        /// One-or-two-sentence plain-language description shown with results.
        public let summary: String

        public init(id: String, displayName: String, riskLevel: RiskLevel, summary: String) {
            self.id = id
            self.displayName = displayName
            self.riskLevel = riskLevel
            self.summary = summary
        }
    }

    public let schemaVersion: Int
    public let modelVersion: String
    /// Square input side length in pixels expected by the model.
    public let inputSize: Int
    public let classes: [ClassInfo]

    public init(schemaVersion: Int, modelVersion: String, inputSize: Int, classes: [ClassInfo]) {
        self.schemaVersion = schemaVersion
        self.modelVersion = modelVersion
        self.inputSize = inputSize
        self.classes = classes
    }

    public init(contentsOf url: URL) throws {
        let data = try Data(contentsOf: url)
        self = try JSONDecoder().decode(ModelManifest.self, from: data)
    }

    public func classInfo(forID id: String) -> ClassInfo? {
        classes.first { $0.id == id }
    }

    /// Throws `ClassifierError.invalidManifest` if the manifest is unusable.
    public func validate() throws {
        guard schemaVersion == 1 else {
            throw ClassifierError.invalidManifest("Unsupported schema version \(schemaVersion)")
        }
        guard !classes.isEmpty else {
            throw ClassifierError.invalidManifest("Manifest declares no classes")
        }
        guard inputSize > 0 else {
            throw ClassifierError.invalidManifest("Invalid input size \(inputSize)")
        }
        guard Set(classes.map(\.id)).count == classes.count else {
            throw ClassifierError.invalidManifest("Duplicate class identifiers")
        }
    }
}

extension ModelManifest {
    /// True when `version` identifies the demo stand-in classifier rather
    /// than a trained model. Used by the UI to mark results and saved scans
    /// that carry no medical meaning — including records persisted by an
    /// older demo build after a real model ships.
    public static func isDemoVersion(_ version: String) -> Bool {
        version.hasPrefix("mock")
    }

    /// Class set used by `MockLesionClassifier`, previews, and tests. Mirrors
    /// `ml/labels.example.yaml`.
    public static let mockOralLesions = ModelManifest(
        schemaVersion: 1,
        modelVersion: "mock-0.0.0",
        inputSize: 384,
        classes: [
            ClassInfo(
                id: "healthy",
                displayName: "No visible lesion",
                riskLevel: .low,
                summary: "No features associated with common oral lesions were detected in this image."
            ),
            ClassInfo(
                id: "aphthous_ulcer",
                displayName: "Aphthous ulcer (canker sore)",
                riskLevel: .low,
                summary: "A common, usually harmless ulcer that typically heals on its own within two weeks."
            ),
            ClassInfo(
                id: "lichen_planus",
                displayName: "Oral lichen planus",
                riskLevel: .moderate,
                summary: "A chronic inflammatory condition that should be monitored by a dental professional."
            ),
            ClassInfo(
                id: "leukoplakia",
                displayName: "Leukoplakia",
                riskLevel: .moderate,
                summary: "A white patch that can occasionally show precancerous changes and warrants professional evaluation."
            ),
            ClassInfo(
                id: "erythroplakia",
                displayName: "Erythroplakia",
                riskLevel: .high,
                summary: "A red patch with a higher likelihood of precancerous change. Seek prompt professional evaluation."
            ),
        ]
    )
}
