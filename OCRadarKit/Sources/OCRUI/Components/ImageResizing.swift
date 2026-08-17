import CoreGraphics
import UIKit

/// Helpers for turning captured or imported images into storable thumbnails
/// and upright `CGImage`s.
enum ImageResizing {
    /// Encodes `image` as JPEG data, scaled down so its longest side is at
    /// most `maxDimension` pixels. Images already within the limit are
    /// re-encoded at their native size. Returns `nil` when encoding fails.
    static func jpegThumbnail(
        from image: CGImage,
        maxDimension: CGFloat = 512,
        compressionQuality: CGFloat = 0.8
    ) -> Data? {
        let width = CGFloat(image.width)
        let height = CGFloat(image.height)
        guard width > 0, height > 0 else { return nil }

        let scale = min(1, maxDimension / max(width, height))
        let targetSize = CGSize(
            width: max(1, (width * scale).rounded(.down)),
            height: max(1, (height * scale).rounded(.down))
        )

        let format = UIGraphicsImageRendererFormat()
        format.scale = 1
        let renderer = UIGraphicsImageRenderer(size: targetSize, format: format)
        let source = UIImage(cgImage: image)
        return renderer.jpegData(withCompressionQuality: compressionQuality) { _ in
            source.draw(in: CGRect(origin: .zero, size: targetSize))
        }
    }

    /// Returns an orientation-normalized (upright) `CGImage` for `image`,
    /// re-rendering only when the backing bitmap is rotated or mirrored.
    /// Use this on photos loaded from the library, whose pixel data often
    /// carries a non-`.up` EXIF orientation.
    static func uprightCGImage(from image: UIImage) -> CGImage? {
        if image.imageOrientation == .up, let cgImage = image.cgImage {
            return cgImage
        }
        let format = UIGraphicsImageRendererFormat()
        format.scale = 1
        let renderer = UIGraphicsImageRenderer(size: image.size, format: format)
        let normalized = renderer.image { _ in
            image.draw(in: CGRect(origin: .zero, size: image.size))
        }
        return normalized.cgImage
    }
}
