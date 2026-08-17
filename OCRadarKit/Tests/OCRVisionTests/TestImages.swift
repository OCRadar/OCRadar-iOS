import CoreGraphics

/// Shared fixture factory for tests that need real `CGImage` inputs.
enum TestImages {
    /// Renders a solid-color BGRA bitmap of the given size and returns it as a
    /// `CGImage`, or `nil` when the bitmap context cannot be created.
    static func solidColor(
        width: Int,
        height: Int,
        red: CGFloat = 0.8,
        green: CGFloat = 0.2,
        blue: CGFloat = 0.4
    ) -> CGImage? {
        guard let colorSpace = CGColorSpace(name: CGColorSpace.sRGB),
              let context = CGContext(
                  data: nil,
                  width: width,
                  height: height,
                  bitsPerComponent: 8,
                  bytesPerRow: 0,
                  space: colorSpace,
                  bitmapInfo: CGImageAlphaInfo.premultipliedFirst.rawValue
                      | CGBitmapInfo.byteOrder32Little.rawValue
              )
        else { return nil }

        context.setFillColor(CGColor(srgbRed: red, green: green, blue: blue, alpha: 1))
        context.fill(CGRect(x: 0, y: 0, width: width, height: height))
        return context.makeImage()
    }
}
