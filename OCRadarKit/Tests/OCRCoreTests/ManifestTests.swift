import Foundation
import OCRCore
import Testing

@Suite("ModelManifest")
struct ManifestTests {
    private let fixtureJSON = """
        {
          "schemaVersion": 1,
          "modelVersion": "test-1.2.3",
          "inputSize": 224,
          "classes": [
            {
              "id": "healthy",
              "displayName": "Common tissue appearance",
              "riskLevel": "low",
              "summary": "Reference category for ordinary-looking mouth tissue."
            },
            {
              "id": "leukoplakia",
              "displayName": "Leukoplakia",
              "riskLevel": "moderate",
              "summary": "Reference category for white patches that do not wipe away."
            },
            {
              "id": "erythroplakia",
              "displayName": "Erythroplakia",
              "riskLevel": "high",
              "summary": "Reference category for red or velvety patches."
            }
          ]
        }
        """

    @Test func decodesEveryFieldFromJSON() throws {
        let data = try #require(fixtureJSON.data(using: .utf8))
        let manifest = try JSONDecoder().decode(ModelManifest.self, from: data)

        #expect(manifest.schemaVersion == 1)
        #expect(manifest.modelVersion == "test-1.2.3")
        #expect(manifest.inputSize == 224)
        try #require(manifest.classes.count == 3)

        let healthy = manifest.classes[0]
        #expect(healthy.id == "healthy")
        #expect(healthy.displayName == "Common tissue appearance")
        #expect(healthy.riskLevel == .low)
        #expect(healthy.summary == "Reference category for ordinary-looking mouth tissue.")

        let leukoplakia = manifest.classes[1]
        #expect(leukoplakia.id == "leukoplakia")
        #expect(leukoplakia.displayName == "Leukoplakia")
        #expect(leukoplakia.riskLevel == .moderate)
        #expect(leukoplakia.summary == "Reference category for white patches that do not wipe away.")

        let erythroplakia = manifest.classes[2]
        #expect(erythroplakia.id == "erythroplakia")
        #expect(erythroplakia.displayName == "Erythroplakia")
        #expect(erythroplakia.riskLevel == .high)
        #expect(erythroplakia.summary == "Reference category for red or velvety patches.")
    }

    @Test func encodeDecodeRoundTripPreservesEquality() throws {
        let original = ModelManifest.mockOralLesions
        let encoded = try JSONEncoder().encode(original)
        let decoded = try JSONDecoder().decode(ModelManifest.self, from: encoded)
        #expect(decoded == original)
    }

    @Test func validateAcceptsMockManifest() {
        #expect(throws: Never.self) {
            try ModelManifest.mockOralLesions.validate()
        }
    }

    @Test func validateRejectsUnsupportedSchemaVersion() {
        // 1 and 2 are both supported; the first unsupported version is 3.
        expectInvalidManifest(makeManifest(schemaVersion: 3))
    }

    @Test func validateAcceptsBothSupportedSchemaVersions() {
        for version in ModelManifest.supportedSchemaVersions {
            #expect(throws: Never.self) { try makeManifest(schemaVersion: version).validate() }
        }
    }

    // MARK: - Abstain threshold

    /// A v1 manifest has no `abstainThreshold` key at all. It must keep
    /// decoding, and must decode to `nil` rather than to some default — a
    /// model exported before the abstain path existed declares no floor, and
    /// inventing one for it would apply a rule nobody measured.
    @Test func decodesSchemaV1ManifestWithNoAbstainThreshold() throws {
        let data = try #require(fixtureJSON.data(using: .utf8))
        let manifest = try JSONDecoder().decode(ModelManifest.self, from: data)
        #expect(manifest.schemaVersion == 1)
        #expect(manifest.abstainThreshold == nil)
        #expect(throws: Never.self) { try manifest.validate() }
    }

    @Test func decodesSchemaV2AbstainThreshold() throws {
        let json = """
            {
              "schemaVersion": 2,
              "modelVersion": "test-2.0.0",
              "inputSize": 384,
              "abstainThreshold": 0.45,
              "classes": [
                {
                  "id": "healthy",
                  "displayName": "Common tissue appearance",
                  "riskLevel": "low",
                  "summary": "Reference category for ordinary-looking mouth tissue."
                }
              ]
            }
            """
        let data = try #require(json.data(using: .utf8))
        let manifest = try JSONDecoder().decode(ModelManifest.self, from: data)
        #expect(manifest.schemaVersion == 2)
        #expect(manifest.abstainThreshold == 0.45)
        #expect(throws: Never.self) { try manifest.validate() }
    }

    /// An explicit JSON null and an absent key must both mean "no threshold",
    /// so the pipeline's choice to omit the key is not load-bearing on the
    /// decoder side.
    @Test func decodesExplicitNullAbstainThresholdAsNil() throws {
        let json = """
            {
              "schemaVersion": 2,
              "modelVersion": "test-2.0.0",
              "inputSize": 384,
              "abstainThreshold": null,
              "classes": [
                {
                  "id": "healthy",
                  "displayName": "Common tissue appearance",
                  "riskLevel": "low",
                  "summary": "Reference category."
                }
              ]
            }
            """
        let data = try #require(json.data(using: .utf8))
        let manifest = try JSONDecoder().decode(ModelManifest.self, from: data)
        #expect(manifest.abstainThreshold == nil)
    }

    @Test(arguments: [-0.01, 1.01, 2.0])
    func validateRejectsOutOfRangeAbstainThreshold(_ threshold: Double) {
        expectInvalidManifest(makeManifest(schemaVersion: 2, abstainThreshold: threshold))
    }

    @Test(arguments: [0.0, 0.45, 1.0])
    func validateAcceptsInRangeAbstainThreshold(_ threshold: Double) {
        #expect(throws: Never.self) {
            try makeManifest(schemaVersion: 2, abstainThreshold: threshold).validate()
        }
    }

    /// Encoding a nil threshold must omit the key entirely, so "no threshold"
    /// has one on-disk form and it is byte-identical to a v1 manifest.
    @Test func encodingOmitsAbsentAbstainThreshold() throws {
        let encoded = try JSONEncoder().encode(makeManifest(abstainThreshold: nil))
        let object = try #require(
            try JSONSerialization.jsonObject(with: encoded) as? [String: Any]
        )
        #expect(object["abstainThreshold"] == nil)
    }

    @Test func roundTripPreservesAbstainThreshold() throws {
        let original = makeManifest(schemaVersion: 2, abstainThreshold: 0.62)
        let decoded = try JSONDecoder().decode(
            ModelManifest.self, from: try JSONEncoder().encode(original)
        )
        #expect(decoded == original)
        #expect(decoded.abstainThreshold == 0.62)
    }

    /// The demo classifier must never abstain: its scores are a function of
    /// the photo's dimensions, so an abstention drawn from them would be as
    /// fabricated as the match it replaced.
    @Test func mockManifestDeclaresNoAbstainThreshold() {
        #expect(ModelManifest.mockOralLesions.abstainThreshold == nil)
    }

    @Test func validateRejectsEmptyClassList() {
        expectInvalidManifest(makeManifest(classIDs: []))
    }

    @Test func validateRejectsNonPositiveInputSize() {
        expectInvalidManifest(makeManifest(inputSize: 0))
    }

    @Test func validateRejectsDuplicateClassIDs() {
        expectInvalidManifest(makeManifest(classIDs: ["healthy", "healthy"]))
    }

    @Test func classInfoLookupFindsKnownID() throws {
        let info = try #require(ModelManifest.mockOralLesions.classInfo(forID: "leukoplakia"))
        #expect(info.id == "leukoplakia")
        #expect(info.displayName == "Leukoplakia")
        #expect(info.riskLevel == .moderate)
    }

    @Test func classInfoLookupMissesUnknownID() {
        #expect(ModelManifest.mockOralLesions.classInfo(forID: "not_a_class") == nil)
    }

    private func makeManifest(
        schemaVersion: Int = 1,
        modelVersion: String = "test-1.0.0",
        inputSize: Int = 224,
        abstainThreshold: Double? = nil,
        classIDs: [String] = ["healthy", "leukoplakia"]
    ) -> ModelManifest {
        ModelManifest(
            schemaVersion: schemaVersion,
            modelVersion: modelVersion,
            inputSize: inputSize,
            abstainThreshold: abstainThreshold,
            classes: classIDs.map { id in
                ModelManifest.ClassInfo(
                    id: id,
                    displayName: id.capitalized,
                    riskLevel: .low,
                    summary: "Summary for \(id)."
                )
            }
        )
    }

    private func expectInvalidManifest(
        _ manifest: ModelManifest,
        sourceLocation: SourceLocation = #_sourceLocation
    ) {
        do {
            try manifest.validate()
            Issue.record(
                "Expected validate() to throw ClassifierError.invalidManifest",
                sourceLocation: sourceLocation
            )
        } catch let error as ClassifierError {
            if case .invalidManifest = error {
                // Expected outcome.
            } else {
                Issue.record(
                    "Expected .invalidManifest, got \(error)",
                    sourceLocation: sourceLocation
                )
            }
        } catch {
            Issue.record(
                "Expected ClassifierError.invalidManifest, got \(error)",
                sourceLocation: sourceLocation
            )
        }
    }
}
