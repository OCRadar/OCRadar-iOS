import Foundation

/// Metadata that ships alongside a trained model. The training pipeline in
/// `ml/` emits this as `ModelManifest.json`; the app decodes it to drive the
/// result UI. The class `id`s must match the class labels embedded in the
/// Core ML model exactly.
public struct ModelManifest: Codable, Sendable, Equatable {
    public struct ClassInfo: Codable, Sendable, Equatable, Identifiable {
        /// Stable identifier; matches the class label embedded in the model.
        public let id: String
        /// Name of the *reference category*, not of anything the user has.
        /// Present it that way — "looks most similar to X", never "you have X".
        public let displayName: String
        public let riskLevel: RiskLevel
        /// One or two plain sentences shown with a result: what this reference
        /// category looks like, and what to do next.
        ///
        /// A summary describes the category, never the person holding the
        /// phone. It must not say what a finding is, how likely it is to be
        /// anything, or what it may become — the app compares images and has no
        /// basis for any of that. "Reference category for white patches that
        /// don't wipe away" is in scope; "a white patch that can show
        /// precancerous changes" is not.
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
            // "No visible lesion" until this pass, and it was the one class
            // name that was not a category label at all. Every other name here
            // labels a set of reference photographs; that one was a *negative
            // finding about the reader's mouth* — the rule-out
            // `MedicalDisclaimer.full` and the LICENSE both disclaim — and it
            // surfaced as the 26pt headline of the Home hero and as a row title,
            // where "Looks most similar to / No visible lesion / Routine" reads
            // as a clearance the app has no basis to give. Its one mitigation
            // was this `summary`, which `ResultView` withholds for demo results
            // — every result in a build with no bundled model — so the app's
            // clearest rule-out shipped with its correction switched off.
            //
            // The name now labels the reference set, exactly as the other four
            // do: photographs of ordinary-looking tissue. Looking similar to
            // those is a comparison; "no lesion is visible" was a finding.
            ClassInfo(
                id: "healthy",
                displayName: "Common tissue appearance",
                riskLevel: .low,
                summary: "Reference category for ordinary-looking mouth tissue with no distinct patch or sore. A close match here is not a clean bill of health."
            ),
            ClassInfo(
                id: "aphthous_ulcer",
                displayName: "Aphthous ulcer (canker sore)",
                riskLevel: .low,
                summary: "Reference category for small round sores inside the mouth. Mention it to a dentist if one lasts more than two weeks."
            ),
            ClassInfo(
                id: "lichen_planus",
                displayName: "Oral lichen planus",
                riskLevel: .moderate,
                summary: "Reference category for lacy white lines or patches, often on the inside of the cheek. Worth asking a dentist about."
            ),
            ClassInfo(
                id: "leukoplakia",
                displayName: "Leukoplakia",
                riskLevel: .moderate,
                summary: "Reference category for white patches that do not wipe away. Worth asking a dentist to take a look."
            ),
            ClassInfo(
                id: "erythroplakia",
                displayName: "Erythroplakia",
                riskLevel: .high,
                summary: "Reference category for red or velvety patches. Worth having a dentist or doctor look at it soon."
            ),
        ]
    )
}
