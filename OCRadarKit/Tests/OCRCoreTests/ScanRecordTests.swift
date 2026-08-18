import Foundation
import OCRCore
import Testing

@Suite("ScanRecord")
struct ScanRecordTests {
    @Test func initFromResultFailsWhenResultHasNoScores() {
        let empty = ClassificationResult(
            scores: [],
            modelVersion: "test-1.0.0",
            inferenceDuration: .zero
        )
        #expect(ScanRecord(result: empty) == nil)
    }

    @Test func initFromResultCopiesTopScoreAndModelVersion() throws {
        let scores = [
            LabelScore(
                id: "healthy",
                displayName: "Common tissue appearance",
                riskLevel: .low,
                probability: 0.3
            ),
            LabelScore(
                id: "leukoplakia",
                displayName: "Leukoplakia",
                riskLevel: .moderate,
                probability: 0.7
            ),
        ]
        let result = ClassificationResult(
            scores: scores,
            modelVersion: "test-9.9.9",
            inferenceDuration: .milliseconds(12)
        )
        let thumbnail = Data([0x0A, 0x0B, 0x0C])

        let record = try #require(ScanRecord(result: result, thumbnailData: thumbnail))

        #expect(record.topClassID == "leukoplakia")
        #expect(record.topClassName == "Leukoplakia")
        #expect(record.riskLevelRaw == RiskLevel.moderate.rawValue)
        #expect(record.riskLevel == .moderate)
        #expect(record.probability == 0.7)
        #expect(record.modelVersion == "test-9.9.9")
        #expect(record.thumbnailData == thumbnail)
    }

    @Test func riskLevelFallsBackToLowForUnknownRawValue() {
        let record = ScanRecord(
            topClassID: "erythroplakia",
            topClassName: "Erythroplakia",
            riskLevel: .high,
            probability: 0.8,
            modelVersion: "test-1.0.0"
        )
        #expect(record.riskLevel == .high)

        record.riskLevelRaw = "not-a-real-level"
        #expect(record.riskLevel == .low)
    }
}
