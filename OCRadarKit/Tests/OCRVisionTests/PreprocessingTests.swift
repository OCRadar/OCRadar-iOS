import CoreGraphics
import CoreVideo
import OCRVision
import Testing

@Suite("ImagePreprocessing")
struct PreprocessingTests {
    @Test func landscapeCropIsCenteredMinimumSquare() {
        let rect = ImagePreprocessing.centerSquareCropRect(width: 400, height: 300)
        #expect(rect == CGRect(x: 50, y: 0, width: 300, height: 300))
    }

    @Test func portraitCropIsCenteredMinimumSquare() {
        let rect = ImagePreprocessing.centerSquareCropRect(width: 300, height: 500)
        #expect(rect == CGRect(x: 0, y: 100, width: 300, height: 300))
    }

    @Test func squareCropCoversTheWholeImage() {
        let rect = ImagePreprocessing.centerSquareCropRect(width: 256, height: 256)
        #expect(rect == CGRect(x: 0, y: 0, width: 256, height: 256))
    }

    @Test func pixelBufferMatchesRequestedSizeAndFormat() throws {
        let image = try #require(TestImages.solidColor(width: 48, height: 48))

        let buffer = try ImagePreprocessing.pixelBuffer(from: image, side: 32)

        #expect(CVPixelBufferGetWidth(buffer) == 32)
        #expect(CVPixelBufferGetHeight(buffer) == 32)
        #expect(CVPixelBufferGetPixelFormatType(buffer) == kCVPixelFormatType_32BGRA)
    }

    @Test func pixelBufferHandlesNonSquareInput() throws {
        let image = try #require(TestImages.solidColor(width: 64, height: 40))

        let buffer = try ImagePreprocessing.pixelBuffer(from: image, side: 24)

        #expect(CVPixelBufferGetWidth(buffer) == 24)
        #expect(CVPixelBufferGetHeight(buffer) == 24)
        #expect(CVPixelBufferGetPixelFormatType(buffer) == kCVPixelFormatType_32BGRA)
    }
}
