import CoreGraphics
import CoreVideo
import Foundation
import OCRCore

/// Pure CoreGraphics/CoreVideo helpers for preparing captured photos for the
/// model. Vision performs its own crop-and-scale during inference
/// (`.centerCrop`), so `CoreMLLesionClassifier` does not call these; they
/// exist for tests and for any future path that feeds an `MLModel` directly.
public enum ImagePreprocessing {
    /// The largest centered square that fits within an image of the given
    /// pixel dimensions.
    ///
    /// Non-positive dimensions produce a zero-sized rect centered on the
    /// given extent.
    public static func centerSquareCropRect(width: Int, height: Int) -> CGRect {
        let side = max(0, min(width, height))
        return CGRect(
            x: (CGFloat(width) - CGFloat(side)) / 2,
            y: (CGFloat(height) - CGFloat(side)) / 2,
            width: CGFloat(side),
            height: CGFloat(side)
        )
    }

    /// Renders `image` into a `side` × `side` BGRA pixel buffer, aspect-fill:
    /// the largest centered square of the source is cropped out and scaled to
    /// fill the buffer exactly.
    ///
    /// - Parameters:
    ///   - image: The source image.
    ///   - side: The edge length of the square output buffer, in pixels.
    /// - Throws: `ClassifierError.preprocessingFailed` when the geometry is
    ///   degenerate (non-positive `side`, empty source image) or the pixel
    ///   buffer or drawing context cannot be created.
    public static func pixelBuffer(from image: CGImage, side: Int) throws -> CVPixelBuffer {
        guard side > 0, image.width > 0, image.height > 0 else {
            throw ClassifierError.preprocessingFailed
        }

        var created: CVPixelBuffer?
        let attributes: [CFString: Any] = [
            kCVPixelBufferCGImageCompatibilityKey: true,
            kCVPixelBufferCGBitmapContextCompatibilityKey: true,
        ]
        let status = CVPixelBufferCreate(
            kCFAllocatorDefault,
            side,
            side,
            kCVPixelFormatType_32BGRA,
            attributes as CFDictionary,
            &created
        )
        guard status == kCVReturnSuccess, let buffer = created else {
            throw ClassifierError.preprocessingFailed
        }

        CVPixelBufferLockBaseAddress(buffer, [])
        defer { CVPixelBufferUnlockBaseAddress(buffer, []) }

        guard
            let base = CVPixelBufferGetBaseAddress(buffer),
            let context = CGContext(
                data: base,
                width: side,
                height: side,
                bitsPerComponent: 8,
                bytesPerRow: CVPixelBufferGetBytesPerRow(buffer),
                space: CGColorSpace(name: CGColorSpace.sRGB) ?? CGColorSpaceCreateDeviceRGB(),
                bitmapInfo: CGImageAlphaInfo.premultipliedFirst.rawValue
                    | CGBitmapInfo.byteOrder32Little.rawValue
            )
        else {
            throw ClassifierError.preprocessingFailed
        }

        // Aspect-fill: scale so the shorter source side spans the buffer,
        // then center. The context clips the overflow, which crops the longer
        // side symmetrically — equivalent to cropping `centerSquareCropRect`
        // and scaling it to `side` × `side`.
        let scale = CGFloat(side) / CGFloat(min(image.width, image.height))
        let drawSize = CGSize(
            width: CGFloat(image.width) * scale,
            height: CGFloat(image.height) * scale
        )
        let drawOrigin = CGPoint(
            x: (CGFloat(side) - drawSize.width) / 2,
            y: (CGFloat(side) - drawSize.height) / 2
        )
        context.interpolationQuality = .high
        context.draw(image, in: CGRect(origin: drawOrigin, size: drawSize))

        return buffer
    }
}
