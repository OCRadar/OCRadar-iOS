import CoreGraphics
import Foundation

/// Deterministic stand-in used when no trained model is bundled, and in
/// previews and tests. Scores are derived from the image's dimensions, so the
/// same input always produces the same output — and the UI can exercise every
/// state without a real model.
///
/// # What that means for a person holding the phone
///
/// The seed is a function of `image.width` and `image.height` and of nothing
/// else. Every photo a given device captures has the same dimensions, so in a
/// build with no bundled model **every photo produces the identical output** —
/// the same closest category, the same percentage, the same tier — whether it
/// is a lesion or a thumbnail of a wall. Repeated identically down a History
/// list and plotted as a flat line on Home, that reads as a stable finding
/// rather than as the noise it is.
///
/// The fix for that is **not** to seed from pixel content. A number that moves
/// when the photo moves is a number that looks measured, and lending fabricated
/// output the appearance of measurement is a larger dishonesty than repeating
/// it. The fix is to say so: every demo surface in the UI states that the score
/// comes from the photo's dimensions rather than from what is in it, and that
/// the same size therefore always yields the same numbers. If this seed ever
/// changes, that copy has to change with it — see `ResultView.demoNotice`,
/// `HistoryDetailView.demoNotice` and `HomeView.modelStatusText`.
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
