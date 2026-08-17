import OCRCore
import OCRUI
import OCRVision
import SwiftData
import SwiftUI

@main
struct OCRadarApp: App {
    /// The inference backend for the whole app. Starts as the deterministic
    /// mock so launch never blocks on model I/O; when a trained Core ML model
    /// is bundled in `Resources/ML/`, it is loaded off the main thread and
    /// swapped in as soon as it is ready. `MLModel(contentsOf:)` can be slow —
    /// especially on the first launch after install, when Core ML may
    /// recompile for the ANE/GPU — so it must never run during App init.
    @State private var classifier: any LesionClassifying = MockLesionClassifier()
    @State private var hasStartedModelLoad = false

    var body: some Scene {
        WindowGroup {
            RootView(classifier: classifier)
                .task {
                    guard !hasStartedModelLoad else { return }
                    hasStartedModelLoad = true
                    let loaded = await Task.detached(priority: .userInitiated) {
                        CoreMLLesionClassifier.bundled()
                    }.value
                    if let loaded {
                        classifier = loaded
                    }
                }
        }
        .modelContainer(for: ScanRecord.self)
    }
}
