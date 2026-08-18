import Foundation
import SwiftData

/// One saved comparison. Stored locally via SwiftData; images and results never
/// leave the device.
///
/// "One saved analysis" until this pass. The app does not analyse anything —
/// it compares a photo with reference images, which is why the button that
/// produces this record says "Compare" and why the sheet that presents it is
/// headed "Visual comparison". A doc comment is where the next author learns
/// the vocabulary, so it uses the same one the screens do.
@Model
public final class ScanRecord {
    public var timestamp: Date
    public var topClassID: String
    public var topClassName: String
    public var riskLevelRaw: String
    public var probability: Double
    public var modelVersion: String
    /// The confidence floor in force when this scan was taken, copied from the
    /// producing model's manifest.
    ///
    /// Optional, and new — SwiftData migrates existing stores by defaulting it
    /// to `nil`, which is correct rather than merely convenient: records saved
    /// before the abstain path existed were produced by models that declared
    /// no floor, so `nil` is what was true of them.
    ///
    /// Stored rather than re-read from the installed classifier for the same
    /// reason `modelVersion` is. History has to stay truthful across builds: a
    /// scan taken under one model must keep being displayed under that model's
    /// rules, not re-judged by whatever is installed the day someone opens it.
    public var abstainThreshold: Double?
    @Attribute(.externalStorage) public var thumbnailData: Data?

    public var riskLevel: RiskLevel {
        RiskLevel(rawValue: riskLevelRaw) ?? .low
    }

    /// True when this scan did not clear the floor its own model declared, and
    /// therefore must not be shown under a category name.
    ///
    /// The stored `topClassID` / `topClassName` are kept regardless — they are
    /// what the ranking was — but every surface that *names* a category checks
    /// this first.
    public var isBelowAbstainThreshold: Bool {
        guard let abstainThreshold else { return false }
        return probability < abstainThreshold
    }

    /// True when this scan was produced by the demo stand-in classifier
    /// rather than a trained model, and therefore carries no medical meaning.
    /// Derived from the stored version so demo records remain identifiable
    /// even after a build with a real model ships.
    public var isDemoResult: Bool { ModelManifest.isDemoVersion(modelVersion) }

    public init(
        timestamp: Date = .now,
        topClassID: String,
        topClassName: String,
        riskLevel: RiskLevel,
        probability: Double,
        modelVersion: String,
        abstainThreshold: Double? = nil,
        thumbnailData: Data? = nil
    ) {
        self.timestamp = timestamp
        self.topClassID = topClassID
        self.topClassName = topClassName
        self.riskLevelRaw = riskLevel.rawValue
        self.probability = probability
        self.modelVersion = modelVersion
        self.abstainThreshold = abstainThreshold
        self.thumbnailData = thumbnailData
    }

    /// Fails when the result carries no scores.
    ///
    /// A result that fell below its model's floor **is** saved, carrying its
    /// top score and the threshold that rejected it. Discarding those would
    /// leave a person who took a photo with no record that they took it, and
    /// History would silently show fewer scans than were made. The record
    /// knows it abstained (`isBelowAbstainThreshold`) and every surface reads
    /// that before naming anything.
    public convenience init?(result: ClassificationResult, thumbnailData: Data? = nil) {
        guard let top = result.top else { return nil }
        self.init(
            topClassID: top.id,
            topClassName: top.displayName,
            riskLevel: top.riskLevel,
            probability: top.probability,
            modelVersion: result.modelVersion,
            abstainThreshold: result.abstainThreshold,
            thumbnailData: thumbnailData
        )
    }
}
