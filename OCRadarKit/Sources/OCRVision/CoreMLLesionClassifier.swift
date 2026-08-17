import CoreGraphics
import CoreML
import Foundation
import OCRCore
import os
import Vision

/// Core ML–backed implementation of `LesionClassifying`.
///
/// Wraps a compiled model (`.mlmodelc`) and its `ModelManifest.json` — both
/// emitted by the `ml/` training pipeline — behind a Vision classification
/// request. All stored state is immutable and `MLModel` is documented as
/// thread-safe for prediction, so instances can be shared freely across
/// actors; the conformance is `@unchecked` only because the underlying
/// framework types predate `Sendable` annotations.
public final class CoreMLLesionClassifier: LesionClassifying, @unchecked Sendable {
    public let kind: ClassifierKind = .coreML
    public let manifest: ModelManifest

    /// The compiled model wrapped for use with Vision requests.
    private let visionModel: VNCoreMLModel

    private static let logger = Logger(
        subsystem: "com.ocradar.OCRVision",
        category: "CoreMLLesionClassifier"
    )

    /// Loads the classifier bundled with the app, if one is present.
    ///
    /// Looks for the compiled model `OralLesionClassifier.mlmodelc` and its
    /// `ModelManifest.json` — Xcode compiles the `.mlpackage` that the `ml/`
    /// training pipeline emits into `OCRadar/Resources/ML/`. Returns `nil`
    /// when either resource is missing, or when initialization throws (the
    /// error is logged); in both cases the app falls back to
    /// `MockLesionClassifier`.
    public static func bundled(in bundle: Bundle = .main) -> CoreMLLesionClassifier? {
        guard
            let modelURL = bundle.url(forResource: "OralLesionClassifier", withExtension: "mlmodelc"),
            let manifestURL = bundle.url(forResource: "ModelManifest", withExtension: "json")
        else {
            logger.debug("No bundled model found; falling back to the mock classifier.")
            return nil
        }
        do {
            return try CoreMLLesionClassifier(modelURL: modelURL, manifestURL: manifestURL)
        } catch {
            logger.error("Failed to load bundled model: \(error.localizedDescription, privacy: .public)")
            return nil
        }
    }

    /// Creates a classifier from a compiled Core ML model and its manifest.
    ///
    /// - Parameters:
    ///   - modelURL: Location of the compiled `.mlmodelc` bundle.
    ///   - manifestURL: Location of the `ModelManifest.json` describing the
    ///     model's classes.
    /// - Throws: `ClassifierError.invalidManifest` when the manifest cannot
    ///   be decoded, fails validation, or disagrees with the class labels
    ///   embedded in the model; `ClassifierError.inferenceFailed` when the
    ///   model cannot be loaded or prepared for Vision.
    public init(modelURL: URL, manifestURL: URL) throws {
        let manifest: ModelManifest
        do {
            manifest = try ModelManifest(contentsOf: manifestURL)
        } catch {
            throw ClassifierError.invalidManifest(
                "Could not decode \(manifestURL.lastPathComponent): \(error.localizedDescription)"
            )
        }
        try manifest.validate()

        let model: MLModel
        do {
            model = try MLModel(contentsOf: modelURL)
        } catch {
            throw ClassifierError.inferenceFailed(
                "Could not load the Core ML model: \(error.localizedDescription)"
            )
        }

        // When the model declares its class labels, they must agree with the
        // manifest — otherwise scores would silently map to the wrong classes.
        if let labels = model.modelDescription.classLabels, !labels.isEmpty {
            let modelIDs = Set(labels.map { String(describing: $0) })
            let manifestIDs = Set(manifest.classes.map(\.id))
            guard modelIDs == manifestIDs else {
                throw ClassifierError.invalidManifest(
                    "Model class labels \(modelIDs.sorted()) do not match manifest class ids \(manifestIDs.sorted())"
                )
            }
        }

        do {
            self.visionModel = try VNCoreMLModel(for: model)
        } catch {
            throw ClassifierError.inferenceFailed(
                "Could not prepare the model for Vision: \(error.localizedDescription)"
            )
        }
        self.manifest = manifest
    }

    /// Runs the model on `image` off the calling actor and maps the resulting
    /// observations through the manifest.
    ///
    /// Vision center-crops and scales the image to the model's input size.
    /// Observations whose identifiers are absent from the manifest are
    /// skipped; the returned scores are sorted most-probable first.
    public func classify(_ image: CGImage) async throws -> ClassificationResult {
        let clock = ContinuousClock()
        let start = clock.now

        let scores = try await Task.detached(priority: .userInitiated) { [self] in
            let request = VNCoreMLRequest(model: visionModel)
            request.imageCropAndScaleOption = .centerCrop

            let handler = VNImageRequestHandler(cgImage: image, options: [:])
            do {
                try handler.perform([request])
            } catch {
                throw ClassifierError.inferenceFailed(error.localizedDescription)
            }

            guard let observations = request.results as? [VNClassificationObservation] else {
                throw ClassifierError.inferenceFailed("The model produced no classification results.")
            }

            return observations.compactMap { observation -> LabelScore? in
                guard let info = manifest.classInfo(forID: observation.identifier) else { return nil }
                return LabelScore(
                    id: info.id,
                    displayName: info.displayName,
                    riskLevel: info.riskLevel,
                    probability: Double(observation.confidence)
                )
            }
        }.value

        return ClassificationResult(
            scores: scores,
            modelVersion: manifest.modelVersion,
            inferenceDuration: start.duration(to: clock.now)
        )
    }
}
