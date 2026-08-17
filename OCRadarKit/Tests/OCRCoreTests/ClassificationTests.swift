import Foundation
import OCRCore
import Testing

@Suite("ClassificationResult")
struct ClassificationTests {
    @Test func initSortsScoresDescendingRegardlessOfInputOrder() {
        let lowest = makeScore(id: "healthy", probability: 0.05)
        let middle = makeScore(id: "leukoplakia", probability: 0.35, riskLevel: .moderate)
        let highest = makeScore(id: "erythroplakia", probability: 0.60, riskLevel: .high)

        let ascending = ClassificationResult(
            scores: [lowest, middle, highest],
            modelVersion: "test-1.0.0",
            inferenceDuration: .zero
        )
        #expect(ascending.scores == [highest, middle, lowest])

        let shuffled = ClassificationResult(
            scores: [middle, highest, lowest],
            modelVersion: "test-1.0.0",
            inferenceDuration: .zero
        )
        #expect(shuffled.scores == [highest, middle, lowest])
    }

    @Test func topIsTheHighestProbabilityScore() {
        let runnerUp = makeScore(id: "healthy", probability: 0.3)
        let winner = makeScore(id: "lichen_planus", probability: 0.7, riskLevel: .moderate)

        let result = ClassificationResult(
            scores: [runnerUp, winner],
            modelVersion: "test-1.0.0",
            inferenceDuration: .milliseconds(8)
        )
        #expect(result.top == winner)
    }

    @Test func riskLevelsCompareLowToModerateToHigh() {
        #expect(RiskLevel.low < RiskLevel.moderate)
        #expect(RiskLevel.moderate < RiskLevel.high)
        #expect(RiskLevel.low < RiskLevel.high)
        #expect(!(RiskLevel.high < RiskLevel.moderate))
        #expect(!(RiskLevel.moderate < RiskLevel.low))
        #expect([RiskLevel.high, .low, .moderate].sorted() == [.low, .moderate, .high])
    }

    private func makeScore(
        id: String,
        probability: Double,
        riskLevel: RiskLevel = .low
    ) -> LabelScore {
        LabelScore(
            id: id,
            displayName: id.capitalized,
            riskLevel: riskLevel,
            probability: probability
        )
    }
}
