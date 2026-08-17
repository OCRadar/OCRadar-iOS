import Foundation
import SwiftData

/// One saved analysis. Stored locally via SwiftData; images and results never
/// leave the device.
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
