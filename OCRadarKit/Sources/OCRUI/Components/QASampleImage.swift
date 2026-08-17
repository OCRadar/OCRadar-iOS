#if DEBUG
import CoreGraphics

/// A deterministic bitmap standing in for a photograph, for QA automation only.
///
/// Two debug hooks need one: `-qaSeedHistory` builds thumbnails for the seeded
/// records, and `-qaScanStage review` needs something for the Scan stage to
/// show. They used to be the same generator written out twice; a screenshot
/// sweep comparing the two surfaces was comparing two different pictures.
///
/// Compiled out of Release entirely.
nonisolated enum QASampleImage {
    /// A 640×640 diagonal salmon-to-maroon ramp — warm and mid-toned on
    /// purpose, so glass chrome laid over it is judged against something with
    /// real luminance rather than against the app's black canvas.
    ///
    /// `data: nil` — Core Graphics allocates and owns the backing store, and
    /// keeps it alive exactly as long as the context needs it.
    ///
    /// This used to hand `CGContext` the base address of a local
    /// `[UInt8]` from inside `withUnsafeMutableBytes`, and then return the
    /// context *out* of that closure to draw into afterwards. The pointer is
    /// only valid for the body of the closure and `CGContext` does not take
    /// ownership of it, so the gradient draw and `makeImage()` below were
    /// writing ~1.6MB through a buffer that was no longer guaranteed to exist.
    /// It is DEBUG-only code, but `RootView` applies `QAAutomationHooks`
    /// unconditionally and its `.task` calls this before it checks any `qa*`
    /// argument — so it ran on every debug launch, not only under QA.
    static func gradient() -> CGImage? {
        let side = 640
        guard let context = CGContext(
            data: nil,
            width: side,
            height: side,
            bitsPerComponent: 8,
            bytesPerRow: side * 4,
            space: CGColorSpace(name: CGColorSpace.sRGB) ?? CGColorSpaceCreateDeviceRGB(),
            bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue
        ) else { return nil }
        let colors = [
            CGColor(red: 0.85, green: 0.45, blue: 0.40, alpha: 1),
            CGColor(red: 0.55, green: 0.20, blue: 0.25, alpha: 1),
        ] as CFArray
        if let gradient = CGGradient(colorsSpace: nil, colors: colors, locations: [0, 1]) {
            context.drawLinearGradient(
                gradient,
                start: .zero,
                end: CGPoint(x: side, y: side),
                options: []
            )
        }
        return context.makeImage()
    }
}
#endif
