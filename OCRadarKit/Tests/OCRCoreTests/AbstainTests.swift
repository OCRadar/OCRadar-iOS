import Foundation
import OCRCore
import Testing

/// The abstain path, at the seam where the decision is actually made.
///
/// The rule is one comparison — top score against the manifest's floor — but
/// the consequences of getting it wrong are asymmetric and neither direction
/// is acceptable: abstaining when the model was confident throws away a usable
/// comparison, and *failing* to abstain puts a category name and a percentage
/// in front of a reader on the strength of a match the pipeline measured as
/// too weak to name. These tests pin both directions, plus the boundary.
@Suite("Abstain path")
struct AbstainTests {
    /// Scores whose highest value is exactly `top`.
    ///
    /// The runners-up are a fixed fraction of `top` rather than a share of the
    /// remaining probability mass, so the ordering holds for every value these
    /// tests use — at `top: 0.31`, splitting the remainder would have put
    /// 0.345 in each of the other two slots and quietly made one of *them* the
    /// top score. The rows therefore do not sum to 1, which is deliberate:
    /// these tests exercise the threshold comparison and the ordering, and
    /// `MockClassifierTests.probabilitiesFormADistribution` is where
    /// normalisation is pinned.
    private func scores(top: Double) -> [LabelScore] {
        let remainder = top / 4.0
        return [
            LabelScore(id: "leukoplakia", displayName: "Leukoplakia", riskLevel: .moderate, probability: top),
            LabelScore(id: "healthy", displayName: "Common tissue appearance", riskLevel: .low, probability: remainder),
            LabelScore(id: "erythroplakia", displayName: "Erythroplakia", riskLevel: .high, probability: remainder),
        ]
    }

    private func result(top: Double, threshold: Double?) -> ClassificationResult {
        ClassificationResult(
            scores: scores(top: top),
            modelVersion: "1.0.0",
            inferenceDuration: .milliseconds(1),
            abstainThreshold: threshold
        )
    }

    // MARK: - ClassificationResult

    @Test func belowThresholdAbstains() {
        let result = result(top: 0.31, threshold: 0.45)
        #expect(result.isBelowAbstainThreshold)
        #expect(result.confidentTop == nil)
        // The raw ranking survives — the similarity bars still render it.
        #expect(result.top?.id == "leukoplakia")
    }

    @Test func aboveThresholdDoesNotAbstain() {
        let result = result(top: 0.72, threshold: 0.45)
        #expect(!result.isBelowAbstainThreshold)
        #expect(result.confidentTop?.id == "leukoplakia")
    }

    /// The comparison is `<`, so a score exactly equal to the floor is kept.
    /// The pipeline picks the smallest threshold that *reaches* its accuracy
    /// target, meaning the boundary value is inside the retained set it was
    /// measured on; abstaining on equality here would apply a stricter rule
    /// than the one the threshold was validated under.
    @Test func exactlyAtThresholdIsRetained() {
        let result = result(top: 0.45, threshold: 0.45)
        #expect(!result.isBelowAbstainThreshold)
        #expect(result.confidentTop != nil)
    }

    /// Every result produced before the abstain path existed, and every demo
    /// result, has no threshold — and must behave exactly as it did before.
    @Test func noThresholdNeverAbstains() {
        for top in [0.001, 0.2, 0.5, 0.99] {
            let result = result(top: top, threshold: nil)
            #expect(!result.isBelowAbstainThreshold)
            #expect(result.confidentTop?.id == result.top?.id)
        }
    }

    @Test func emptyScoresNeverAbstain() {
        let result = ClassificationResult(
            scores: [], modelVersion: "1.0.0", inferenceDuration: .zero, abstainThreshold: 0.5
        )
        // No scores is its own state with its own screen; it must not be
        // routed into the abstaining branch, which promises a ranking exists.
        #expect(!result.isBelowAbstainThreshold)
        #expect(result.confidentTop == nil)
        #expect(result.top == nil)
    }

    @Test func mockClassifierNeverAbstains() async throws {
        let image = try #require(TestImages.solidColor(width: 384, height: 384))
        let result = try await MockLesionClassifier().classify(image)
        #expect(result.abstainThreshold == nil)
        #expect(!result.isBelowAbstainThreshold)
    }

    // MARK: - ScanRecord

    @Test func recordPersistsTheThresholdInForce() throws {
        let source = result(top: 0.31, threshold: 0.45)
        let record = try #require(ScanRecord(result: source))
        #expect(record.abstainThreshold == 0.45)
        #expect(record.isBelowAbstainThreshold)
        // The closest category is still stored: it is what the ranking was,
        // and History needs a record that a scan happened at all.
        #expect(record.topClassID == "leukoplakia")
        #expect(record.probability == 0.31)
    }

    @Test func recordAboveThresholdDoesNotAbstain() throws {
        let record = try #require(ScanRecord(result: result(top: 0.9, threshold: 0.45)))
        #expect(!record.isBelowAbstainThreshold)
    }

    /// Records written before this field existed decode with a nil threshold,
    /// which is correct rather than merely convenient: they were produced by
    /// models that declared no floor.
    @Test func legacyRecordWithNoThresholdNeverAbstains() {
        let record = ScanRecord(
            topClassID: "leukoplakia",
            topClassName: "Leukoplakia",
            riskLevel: .moderate,
            probability: 0.04,
            modelVersion: "0.9.0"
        )
        #expect(record.abstainThreshold == nil)
        #expect(!record.isBelowAbstainThreshold)
    }

    // MARK: - Wording

    /// The abstaining surfaces inherit their words from `MedicalDisclaimer`;
    /// these assertions are what makes "no screen may paraphrase" checkable
    /// rather than merely stated. They pin the *position* the strings encode,
    /// not their prose — the wording may be revised, but a revision that says
    /// the app found nothing, or that names a condition, has to fail here.
    @Test func noConfidentMatchCopyDoesNotRuleAnythingOut() {
        let statement = MedicalDisclaimer.noConfidentMatch.lowercased()
        // Must not read as a clearance.
        #expect(!statement.contains("nothing is wrong"))
        #expect(!statement.contains("no lesion"))
        #expect(!statement.contains("you are fine"))
        #expect(!statement.contains("all clear"))
        // Must say the two things that keep it from being read either way.
        #expect(statement.contains("not a finding"))
        #expect(statement.contains("concerns you"))
    }

    @Test func noConfidentMatchCopyNamesNoCategory() {
        let statement = MedicalDisclaimer.noConfidentMatch.lowercased()
        for classInfo in ModelManifest.mockOralLesions.classes {
            #expect(!statement.contains(classInfo.displayName.lowercased()))
        }
    }

    /// The tier slot never goes blank: a row whose guidance is empty where
    /// every other row carries an action reads as "nothing to do here".
    @Test func noConfidentMatchSuppliesAnAction() {
        #expect(!MedicalDisclaimer.noConfidentMatchNextStep.isEmpty)
        #expect(!MedicalDisclaimer.noConfidentMatchRowTitle.isEmpty)
        #expect(!MedicalDisclaimer.noConfidentMatchTitle.isEmpty)
    }
}
