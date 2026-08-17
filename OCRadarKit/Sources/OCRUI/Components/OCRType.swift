import SwiftUI

// MARK: - The type scale

/// One row of `design/README.md`'s type table: the point size the design
/// specifies, the weight it is set in, and the system text style whose Dynamic
/// Type curve it grows along.
///
/// **Why the app's type is not a set of `Font` constants any more.** SwiftUI's
/// `Font.system(size:)` is a *fixed* size. Unlike a text style (`.body`,
/// `.title2`) or `Font.custom(_:size:relativeTo:)` it does not respond to
/// Dynamic Type at all — and every font in this package was declared that way,
/// while eight container dimensions scaled with `@ScaledMetric`. At
/// accessibility sizes the boxes therefore grew and the words inside them did
/// not: on Home the "Earlier scans" row's intrinsic width outgrew the display,
/// `RootView`'s root `ZStack` sized itself to that widest child and centred it,
/// and roughly 40pt was clipped off *both* edges of the entire app — the
/// floating tab bar included. "91%", the one datum the screen exists to show,
/// rendered as "1%".
///
/// A `Font` value cannot fix that on its own, because a `Font` has no access to
/// the environment. The size comes from a `@ScaledMetric` instead — which
/// returns the design's own number unchanged at the default text size and grows
/// it along the named style's curve above that — and a `ViewModifier` is the
/// only thing that can hold one. That is the same split `OCRLeading` and
/// `OCRBaselineRise` below already use.
///
/// Tracking stays at the call site — `.ocrFont(.rowTitle).tracking(-0.2)` — as
/// it has no font-level representation.
///
/// `nonisolated` because `OCRUI` compiles with `defaultIsolation(MainActor)`
/// and these are plain value constants.
nonisolated struct OCRTextStyle: Equatable {
    /// The design's point size, rendered exactly at the default text size.
    var size: CGFloat
    var weight: Font.Weight
    /// The Dynamic Type curve this role scales along. Roles are mapped to the
    /// nearest system style, so a hero numeral grows at a display rate and body
    /// copy grows at a reading rate rather than all of them growing alike.
    var relativeTo: Font.TextStyle

    init(_ size: CGFloat, _ weight: Font.Weight = .regular, relativeTo: Font.TextStyle) {
        self.size = size
        self.weight = weight
        self.relativeTo = relativeTo
    }

    /// Hero confidence numeral — 76/600, `design/README.md`.
    static let heroNumeral = OCRTextStyle(76, .semibold, relativeTo: .largeTitle)
    /// Screen title and result class name — 26/600.
    static let screenTitle = OCRTextStyle(26, .semibold, relativeTo: .title)
    /// Section head, e.g. "Earlier scans" — 21/600.
    static let sectionHead = OCRTextStyle(21, .semibold, relativeTo: .title2)
    /// Card title and wordmark — 16.5/600.
    static let cardTitle = OCRTextStyle(16.5, .semibold, relativeTo: .headline)
    /// Row title — 16/500.
    static let rowTitle = OCRTextStyle(16, .medium, relativeTo: .body)
    /// List value / class name — 15.5/400.
    static let listValue = OCRTextStyle(15.5, .regular, relativeTo: .body)
    /// Body copy — 14.5/400, line-height 1.5.
    static let body = OCRTextStyle(14.5, .regular, relativeTo: .body)
    /// Header subtitle and row meta — 13.5.
    static let meta = OCRTextStyle(13.5, .regular, relativeTo: .subheadline)
    /// The label above a card group — 13/600.
    static let sectionLabel = OCRTextStyle(13, .semibold, relativeTo: .footnote)
    /// Footnotes and legal copy — 13/400, line-height 1.6.
    static let footnote = OCRTextStyle(13, .regular, relativeTo: .caption)

    /// The same role at another weight — the type table gives row meta as
    /// `500/400`, so both ends of that are values the design sanctions.
    func weight(_ weight: Font.Weight) -> OCRTextStyle {
        var copy = self
        copy.weight = weight
        return copy
    }

    /// The same role and the same scaling curve at a neighbouring point size —
    /// for the handful of sizes the table gives as a range (15.5–16, 14.5,
    /// 11.5–12.5) rather than as a single number.
    func size(_ size: CGFloat) -> OCRTextStyle {
        var copy = self
        copy.size = size
        return copy
    }
}

extension View {
    /// Sets the type role for this view's text, scaled for the reader's
    /// Dynamic Type setting. Replaces `.font(.ocr…())`.
    func ocrFont(_ style: OCRTextStyle) -> some View {
        modifier(OCRScaledFont(style: style))
    }
}

/// Backs `View.ocrFont(_:)`.
private struct OCRScaledFont: ViewModifier {
    @ScaledMetric private var size: CGFloat
    private let weight: Font.Weight

    init(style: OCRTextStyle) {
        _size = ScaledMetric(wrappedValue: style.size, relativeTo: style.relativeTo)
        weight = style.weight
    }

    func body(content: Content) -> some View {
        content.font(.system(size: size, weight: weight))
    }
}

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
