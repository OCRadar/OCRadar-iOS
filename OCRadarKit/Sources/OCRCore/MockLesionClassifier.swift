import CoreGraphics
import Foundation

/// Deterministic classifier used when no trained model is bundled, and in
/// previews and tests. Scores are derived from the image's dimensions, so the
/// same input always produces the same output — and the UI can exercise every
/// state without a real model.
public struct MockLesionClassifier: LesionClassifying {
    public let kind: ClassifierKind = .mock
    public let manifest: ModelManifest = .mockOralLesions

    public init() {}

    public func classify(_ image: CGImage) async throws -> ClassificationResult {
        let clock = ContinuousClock()
        let start = clock.now

        // Simulate a realistic inference delay so loading states are visible.
        try? await Task.sleep(for: .milliseconds(200))

        var seed = UInt64(image.width) &* 2_654_435_761 &+ UInt64(image.height) &* 40_503
        let raw: [Double] = manifest.classes.map { _ in
            seed = seed &* 6_364_136_223_846_793_005 &+ 1_442_695_040_888_963_407
            return Double(seed % 1000) / 1000.0 + 0.001
        }
        let total = raw.reduce(0, +)

        let scores = zip(manifest.classes, raw).map { cls, value in
            LabelScore(
                id: cls.id,
                displayName: cls.displayName,
                riskLevel: cls.riskLevel,
                probability: value / total
            )
        }

        return ClassificationResult(
            scores: scores,
            modelVersion: manifest.modelVersion,
            inferenceDuration: start.duration(to: clock.now)
        )
    }
}
