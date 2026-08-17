import SwiftUI

/// Leading (line-height) for multi-line copy, expressed as the design's own
/// ratios instead of a per-call-site `lineSpacing` literal.
///
/// `design/README.md`'s type table gives two ratios and only two — body
/// **1.5** and footnote **1.6** — but `lineSpacing` is not a line height: it is
/// the *extra* space SwiftUI adds on top of the font's natural line box. So the
/// same ratio needs a different literal at every size, and the package had
/// drifted to five of them (3, 4, 6, 7, 8) across four sizes, with the *same*
/// disclaimer string set at 1.50 on Home and 1.81 on Settings. That is the
/// difference between copy that is typeset and copy that is merely placed.
///
/// These modifiers do the subtraction instead, so a call site names the ratio it
/// wants and the size it is setting, and two screens showing one string can no
/// longer disagree.
///
/// **Why it is a `ViewModifier` and not a function.** The spacing has to grow
/// with Dynamic Type — a fixed 4pt gap between 13pt lines is a 1.5 ratio, and
/// between 34pt lines at AX5 it is 1.31 — and only a `ViewModifier` can hold the
/// `@ScaledMetric` that does that.
private struct OCRLeading: ViewModifier {
    /// SF Pro's natural line box as a fraction of the point size. Measured
    /// against the values the package already shipped: at 13.5/1.5 this yields
    /// 4.15 where the demo notice used 4, and at 15/1.6 it yields 6.11 where the
    /// disclaimer sheet used 6 — i.e. the two places that were already on-ratio
    /// stay where they are, and only the strays move.
    static let naturalLineHeight: CGFloat = 1.1929

    @ScaledMetric private var spacing: CGFloat

    init(size: CGFloat, ratio: CGFloat) {
        _spacing = ScaledMetric(
            wrappedValue: max(0, size * (ratio - Self.naturalLineHeight)),
            relativeTo: .body
        )
    }

    func body(content: Content) -> some View {
        content.lineSpacing(spacing)
    }
}

extension View {
    /// Sets leading to `ratio × size`, minus what the font already draws.
    /// Pass the point size the text is actually set at.
    func ocrLeading(_ ratio: CGFloat, size: CGFloat) -> some View {
        modifier(OCRLeading(size: size, ratio: ratio))
    }

    /// Body copy: `design/README.md`'s line-height **1.5**.
    func ocrBodyLeading(size: CGFloat) -> some View {
        ocrLeading(1.5, size: size)
    }

    /// Footnotes and legal copy: `design/README.md`'s line-height **1.6**.
    func ocrFootnoteLeading(size: CGFloat) -> some View {
        ocrLeading(1.6, size: size)
    }

    /// Optically centres a non-text element — a glyph, a marker dot, a chevron —
    /// on the **cap band of the text it belongs to**, when it sits in an
    /// `HStack(alignment: .firstTextBaseline)`.
    ///
    /// This is the anchoring rule for every piece of row chrome. A trailing
    /// chevron centred on the *row box* has no relationship to anything: on a
    /// two-line row it lands in the gap between the title and the meta line, and
    /// on a row with a 52pt avatar it lands wherever the avatar happens to put
    /// the row's centre. Centred on the title's cap band it reads as belonging
    /// to the title, which is what it discloses.
    ///
    /// SF Pro's cap height is ~0.70em, so the cap band's centre sits `0.35 ×
    /// size` above the baseline. The rise scales with Dynamic Type, so the
    /// relationship holds at every text size rather than only the default one.
    ///
    /// Inert — and therefore safe — in a stack that is not baseline-aligned: an
    /// alignment guide for an alignment the stack does not use is never read.
    func ocrCapCentred(on textSize: CGFloat = 16) -> some View {
        modifier(OCRBaselineRise(textSize: textSize, fraction: OCRBaselineRise.capCentre))
    }

    /// The same anchoring, but on the **x-height** band rather than the cap
    /// band — for an element that stands between words rather than beside a
    /// title, such as the separator dots in `OCRMetaLine`. SF Pro's x-height is
    /// ~0.52em, so its centre sits `0.26 × size` above the baseline.
    func ocrXHeightCentred(on textSize: CGFloat) -> some View {
        modifier(OCRBaselineRise(textSize: textSize, fraction: OCRBaselineRise.xHeightCentre))
    }
}

/// Backs `View.ocrCapCentred(on:)` and `View.ocrXHeightCentred(on:)`. A
/// `ViewModifier` so the rise can scale with Dynamic Type — see `OCRLeading`
/// for the same reason.
private struct OCRBaselineRise: ViewModifier {
    /// Half of SF Pro's ~0.70em cap height.
    static let capCentre: CGFloat = 0.35
    /// Half of SF Pro's ~0.52em x-height.
    static let xHeightCentre: CGFloat = 0.26

    @ScaledMetric private var rise: CGFloat

    init(textSize: CGFloat, fraction: CGFloat) {
        _rise = ScaledMetric(
            wrappedValue: textSize * fraction,
            relativeTo: .body
        )
    }

    func body(content: Content) -> some View {
        // Read out of the modifier before the closure: SwiftUI hands the guide
        // builder out without isolation, and `OCRUI` compiles with
        // `defaultIsolation(MainActor)`, so touching `rise` inside it would be
        // a main-actor reference from a `Sendable` closure.
        let rise = rise
        return content.alignmentGuide(.firstTextBaseline) { dimensions in
            dimensions[VerticalAlignment.center] + rise
        }
    }
}
