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
    @Attribute(.externalStorage) public var thumbnailData: Data?

    public var riskLevel: RiskLevel {
        RiskLevel(rawValue: riskLevelRaw) ?? .low
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
        thumbnailData: Data? = nil
    ) {
        self.timestamp = timestamp
        self.topClassID = topClassID
        self.topClassName = topClassName
        self.riskLevelRaw = riskLevel.rawValue
        self.probability = probability
        self.modelVersion = modelVersion
        self.thumbnailData = thumbnailData
    }

    /// Fails when the result carries no scores.
    public convenience init?(result: ClassificationResult, thumbnailData: Data? = nil) {
        guard let top = result.top else { return nil }
        self.init(
            topClassID: top.id,
            topClassName: top.displayName,
            riskLevel: top.riskLevel,
            probability: top.probability,
            modelVersion: result.modelVersion,
            thumbnailData: thumbnailData
        )
    }
}
