import CoreGraphics
import Foundation
import OCRCore
import Testing

@Suite("MockLesionClassifier")
struct MockClassifierTests {
    @Test func identifiesAsMockWithMockManifest() {
        let classifier = MockLesionClassifier()
        #expect(classifier.kind == .mock)
        #expect(classifier.manifest == .mockOralLesions)
    }

    @Test func sameSizeImagesYieldIdenticalScores() async throws {
        let classifier = MockLesionClassifier()
        let image = try #require(TestImages.solidColor(width: 120, height: 90))
        let differentlyColored = try #require(
            TestImages.solidColor(width: 120, height: 90, red: 0.1, green: 0.9, blue: 0.3)
        )

        let first = try await classifier.classify(image)
        let second = try await classifier.classify(image)
        let third = try await classifier.classify(differentlyColored)

        #expect(first.scores == second.scores)
        #expect(first.scores == third.scores)
    }

    @Test func probabilitiesFormADistribution() async throws {
        let classifier = MockLesionClassifier()
        let image = try #require(TestImages.solidColor(width: 200, height: 150))

        let result = try await classifier.classify(image)

        #expect(result.scores.count == ModelManifest.mockOralLesions.classes.count)
        let total = result.scores.reduce(0) { $0 + $1.probability }
        #expect(abs(total - 1.0) < 1e-6)
        for score in result.scores {
            #expect(score.probability >= 0)
            #expect(score.probability <= 1)
        }
    }

    @Test func scoresAreSortedDescending() async throws {
        let classifier = MockLesionClassifier()
        let image = try #require(TestImages.solidColor(width: 96, height: 128))

        let result = try await classifier.classify(image)

        let probabilities = result.scores.map(\.probability)
        #expect(probabilities == probabilities.sorted(by: >))
        #expect(result.modelVersion == ModelManifest.mockOralLesions.modelVersion)
    }
}
