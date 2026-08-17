// swift-tools-version: 6.2
import PackageDescription

let package = Package(
    name: "OCRadarKit",
    platforms: [.iOS(.v26)],
    products: [
        .library(name: "OCRCore", targets: ["OCRCore"]),
        .library(name: "OCRCapture", targets: ["OCRCapture"]),
        .library(name: "OCRVision", targets: ["OCRVision"]),
        .library(name: "OCRUI", targets: ["OCRUI"]),
    ],
    targets: [
        // Domain types and the classifier seam. Foundation-level, UI-free.
        .target(name: "OCRCore"),
        // AVFoundation camera session + SwiftUI preview surface.
        .target(name: "OCRCapture"),
        // Core ML / Vision inference backend.
        .target(name: "OCRVision", dependencies: ["OCRCore"]),
        // All screens and components. MainActor by default.
        .target(
            name: "OCRUI",
            dependencies: ["OCRCore", "OCRCapture"],
            swiftSettings: [.defaultIsolation(MainActor.self)]
        ),
        .testTarget(name: "OCRCoreTests", dependencies: ["OCRCore"]),
        .testTarget(name: "OCRVisionTests", dependencies: ["OCRVision"]),
    ]
)
