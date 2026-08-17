import Foundation
import OCRVision
import Testing

@Suite("CoreMLLesionClassifier bundling")
struct BundledModelTests {
    @Test func bundledReturnsNilWhenBundleHasNoModelResources() throws {
        // Bundle.module is only synthesized for targets that declare
        // resources, so build an empty bundle from a temporary directory.
        let directory = FileManager.default.temporaryDirectory
            .appending(path: "BundledModelTests-\(UUID().uuidString)", directoryHint: .isDirectory)
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: directory) }

        let emptyBundle = try #require(Bundle(url: directory))
        #expect(CoreMLLesionClassifier.bundled(in: emptyBundle) == nil)
    }
}
