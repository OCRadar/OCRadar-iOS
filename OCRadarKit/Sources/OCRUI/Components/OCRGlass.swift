import SwiftUI

/// Liquid Glass for one piece of floating chrome, with the flat opaque fill it
/// replaced as its Reduce Transparency fallback.
///
/// **What is allowed to use this.** Chrome only — things that float *above* the
/// page: the tab bar, circular icon buttons on a gradient, the Scan status pill
/// and shutter ring, the sheets' Done capsules, secondary actions over a photo.
/// Content surfaces (`OCRCard`, the chart card, the header bands, the gradient
/// hero, `OCRDemoNotice`) stay flat and opaque — `design/README.md` measured
/// their contrast against a known fill, and glass would put that measurement at
/// the mercy of whatever scrolls behind it.
///
/// **Always `.regular`, never `.clear`.** The canvas is true black and the
/// camera stage is `#0C0C0F`; clear glass over that has essentially nothing to
/// refract and renders as an all-but-invisible smudge. Regular glass keeps its
/// own luminance adaptation and specular edge, which is what holds these labels
/// above the spec's 4.5:1 floor over both black and a bright camera frame.
///
/// **`fallback` is an opaque-enough flat fill, spelled out at each call site.**
/// With Reduce Transparency on, every surface here returns to a flat treatment —
/// usually the exact fill the restyle shipped, because that fill was measured
/// against a known backdrop.
///
/// Where it was *not* measured against a known backdrop, the fallback is an
/// opaque token instead of the design's translucent wash, and the call site says
/// why: the Scan stage is a live camera frame or the user's own photograph
/// (`ScanView` → `Theme.surfaceRaised`), and the sheets' Done capsule sits on
/// the light end of `Theme.hero` (`OCRSheetHeader` → `Theme.gradientControlFill`).
/// A wash drawn over a dark stand-in composites straight up with a bright
/// backdrop, which is the failure the glass tints exist to prevent — turning an
/// accessibility setting **on** must never drop a label below the spec's floor.
///
/// `reduceTransparency` is passed in rather than read here so one
/// `@Environment` read per screen can drive a whole cluster of controls; two
/// halves of the same control can then never disagree about which treatment
/// they are in.
///
/// `nonisolated` (like `Theme`) so it can also be applied from the nonisolated
/// contexts SwiftUI hands out — `ButtonStyle.makeBody` and `PhotosPicker`'s
/// `@Sendable` label builder both reach for it.
nonisolated struct OCRGlassBackground<S: Shape>: ViewModifier {
    let shape: S
    let tint: Color?
    let interactive: Bool
    let fallback: Color
    let reduceTransparency: Bool

    @ViewBuilder
    func body(content: Content) -> some View {
        if reduceTransparency {
            content.background(fallback, in: shape)
        } else {
            content.glassEffect(resolvedGlass, in: shape)
        }
    }

    private var resolvedGlass: Glass {
        let base = tint.map { Glass.regular.tint($0) } ?? .regular
        return interactive ? base.interactive() : base
    }
}

nonisolated extension View {
    /// Applies `OCRGlassBackground`. See that type for what may use it, why
    /// every surface is `.regular`, and why the fallback colour is named at the
    /// call site.
    func ocrGlass(
        _ shape: some Shape,
        tint: Color? = nil,
        interactive: Bool = false,
        fallback: Color,
        reduceTransparency: Bool
    ) -> some View {
        modifier(
            OCRGlassBackground(
                shape: shape,
                tint: tint,
                interactive: interactive,
                fallback: fallback,
                reduceTransparency: reduceTransparency
            )
        )
    }
}
