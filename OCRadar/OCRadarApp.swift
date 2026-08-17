import OCRCore
import OCRUI
import OCRVision
import SwiftData
import SwiftUI

@main
struct OCRadarApp: App {
    /// Uses the trained Core ML model when one is bundled in `Resources/ML/`;
    /// otherwise falls back to the deterministic mock so the app stays fully
    /// navigable in demo mode.
    private let classifier: any LesionClassifying = OCRadarApp.makeClassifier()

    var body: some Scene {
        WindowGroup {
            RootView(classifier: classifier)
        }
        .modelContainer(for: ScanRecord.self)
    }

    private static func makeClassifier() -> any LesionClassifying {
        if let model = CoreMLLesionClassifier.bundled() {
            return model
        }
        return MockLesionClassifier()
    }
}
