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
              "displayName": "No visible lesion",
              "riskLevel": "low",
              "summary": "No features associated with common oral lesions were detected."
            },
            {
              "id": "leukoplakia",
              "displayName": "Leukoplakia",
              "riskLevel": "moderate",
              "summary": "A white patch that warrants professional evaluation."
            },
            {
              "id": "erythroplakia",
              "displayName": "Erythroplakia",
              "riskLevel": "high",
              "summary": "A red patch. Seek prompt professional evaluation."
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
        #expect(healthy.displayName == "No visible lesion")
        #expect(healthy.riskLevel == .low)
        #expect(healthy.summary == "No features associated with common oral lesions were detected.")

        let leukoplakia = manifest.classes[1]
        #expect(leukoplakia.id == "leukoplakia")
        #expect(leukoplakia.displayName == "Leukoplakia")
        #expect(leukoplakia.riskLevel == .moderate)
        #expect(leukoplakia.summary == "A white patch that warrants professional evaluation.")

        let erythroplakia = manifest.classes[2]
        #expect(erythroplakia.id == "erythroplakia")
        #expect(erythroplakia.displayName == "Erythroplakia")
        #expect(erythroplakia.riskLevel == .high)
        #expect(erythroplakia.summary == "A red patch. Seek prompt professional evaluation.")
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
        expectInvalidManifest(makeManifest(schemaVersion: 2))
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
        classIDs: [String] = ["healthy", "leukoplakia"]
    ) -> ModelManifest {
        ModelManifest(
            schemaVersion: schemaVersion,
            modelVersion: modelVersion,
            inputSize: inputSize,
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
