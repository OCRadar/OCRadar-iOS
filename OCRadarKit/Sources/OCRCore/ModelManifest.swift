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
    /// Probability below which the closest category is *not* a match, and the
    /// honest answer is that no comparison could be made with confidence.
    ///
    /// Added in schema v2, and optional in both senses: absent from v1
    /// manifests, and absent from a v2 manifest when the pipeline's threshold
    /// criterion selected none. `nil` means the model declares no floor, and
    /// the app behaves as it did before this field existed — it shows the
    /// closest category however weak the match.
    ///
    /// The value is compared against a **calibrated** probability. The
    /// training pipeline fits a temperature on validation data, bakes it into
    /// the exported Core ML graph, and only then picks this threshold, so the
    /// number the app compares is drawn from the same distribution the
    /// threshold was chosen on. A manifest carrying a threshold from one model
    /// beside another model's weights is the failure this pairing exists to
    /// prevent; `ml/` emits both together and never separately.
    public let abstainThreshold: Double?
    public let classes: [ClassInfo]

    public init(
        schemaVersion: Int,
        modelVersion: String,
        inputSize: Int,
        abstainThreshold: Double? = nil,
        classes: [ClassInfo]
    ) {
        self.schemaVersion = schemaVersion
        self.modelVersion = modelVersion
        self.inputSize = inputSize
        self.abstainThreshold = abstainThreshold
        self.classes = classes
    }

    public init(contentsOf url: URL) throws {
        let data = try Data(contentsOf: url)
        self = try JSONDecoder().decode(ModelManifest.self, from: data)
    }

    public func classInfo(forID id: String) -> ClassInfo? {
        classes.first { $0.id == id }
    }

    /// Schema versions this build knows how to read.
    ///
    /// v1 and v2 differ only by the optional `abstainThreshold`, so a v1
    /// manifest is a valid v2 manifest that declares no threshold and is
    /// accepted unchanged. Keeping both readable is what lets a model exported
    /// before the abstain path shipped keep working in a build that has it.
    public static let supportedSchemaVersions: ClosedRange<Int> = 1...2

    /// Throws `ClassifierError.invalidManifest` if the manifest is unusable.
    public func validate() throws {
        guard Self.supportedSchemaVersions.contains(schemaVersion) else {
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
        // A threshold outside 0...1 cannot be compared against a probability.
        // Rejecting the manifest is the safe failure: the app falls back to the
        // mock, which is clearly labelled as carrying no medical meaning,
        // rather than loading a real model whose abstain rule is nonsense.
        if let abstainThreshold {
            guard (0.0...1.0).contains(abstainThreshold) else {
                throw ClassifierError.invalidManifest(
                    "Abstain threshold \(abstainThreshold) is outside 0...1"
                )
            }
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
    ///
    /// It declares **no** `abstainThreshold`, and that is deliberate. The demo
    /// scores are a function of the photo's dimensions, so an abstention drawn
    /// from them would be as fabricated as the match it replaced — and a
    /// screen that says "no confident match" is far easier to read as a real
    /// measurement than one that says 32%. The demo notices already state that
    /// these numbers mean nothing; adding a second fabricated verdict on top
    /// would dress the same fiction as caution.
    public static let mockOralLesions = ModelManifest(
        schemaVersion: 2,
        modelVersion: "mock-0.0.0",
        inputSize: 384,
        abstainThreshold: nil,
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
