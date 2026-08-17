import OCRCore
import SwiftUI

/// Design tokens for the app-wide restyle: a dark-only palette, the logo-derived
/// gradients, radii, spacing steps and motion curves. Values are transcribed
/// from `design/README.md`, where every contrast ratio was measured — in
/// particular the third gradient stop must stay at `#96554F`, because at the
/// earlier `#D08A6E` white labels measured 2.8–3.7:1.
nonisolated enum Theme {
    // MARK: Colour
    static let canvas = Color.black
    static let surface = Color(hex: 0x131316)
    static let surfaceRaised = Color(hex: 0x26262C)
    static let tabBarFill = Color(hex: 0x16161A)
    static let divider = Color(hex: 0x1E1E24)

    static let textPrimary = Color.white
    static let textSecondary = Color(hex: 0x8E8E93)   // 6.44:1 on black
    static let textTertiary = Color(hex: 0x76767E)    // 4.60:1 on black — lightest allowed for text
    static let numeralMuted = Color(hex: 0xE8E6EC)
    static let chevron = Color(hex: 0x5A5A62)

    static let accent = Color(hex: 0xC77BE8)
    static let accentHover = Color(hex: 0xDBA5F0)     // link pressed
    static let salmon = Color(hex: 0xE39B7B)          // data only, never behind text
    static let mint = Color(hex: 0x5FD3A6)            // live-model indicator

    static let stageFill = Color(hex: 0x0C0C0F)
    static let stageBorder = Color(hex: 0x1C1C22)
    static let radarRing = Color(hex: 0x26262E)

    /// Outline of the demo notice card — a hair above `divider` so the card
    /// reads as outlined rather than filled.
    static let noticeBorder = Color(hex: 0x2A2A2E)

    // MARK: Gradients — sampled from the ocrnew logo asset.
    //
    // All three surface gradients run at CSS `152deg`. A `LinearGradient` with
    // `.topLeading`/`.bottomTrailing` is NOT that angle: those unit points chase
    // the box's own diagonal, so the ramp tilts with the aspect ratio (about
    // 40° off vertical on the Home hero, 69° on a header band). `OCRGradient`
    // resolves the true 152° gradient line against the measured size instead.

    static let heroStops: [Gradient.Stop] = [
        .init(color: Color(hex: 0x4B2E8F), location: 0),
        .init(color: Color(hex: 0x8B4E9E), location: 0.52),
        .init(color: Color(hex: 0x96554F), location: 1)
    ]

    static let bandStops: [Gradient.Stop] = [
        .init(color: Color(hex: 0x4B2E8F), location: 0),
        .init(color: Color(hex: 0x8B4E9E), location: 0.62),
        .init(color: Color(hex: 0x96554F), location: 1)
    ]

    static let buttonStops: [Gradient.Stop] = [
        .init(color: Color(hex: 0x7C3FBF), location: 0),
        .init(color: Color(hex: 0x96554F), location: 1)
    ]

    /// Home hero panel, Result and Scan-detail sheet headers.
    static var hero: OCRGradient { OCRGradient(stops: heroStops) }
    /// Scan / History / Settings header bands, disclaimer sheet header.
    static var band: OCRGradient { OCRGradient(stops: bandStops) }
    /// Filled buttons, shutter, History avatar for the newest scan.
    static var button: OCRGradient { OCRGradient(stops: buttonStops) }

    /// Fill of the Result sheet's top-class bar only. Horizontal, unlike the
    /// diagonal surface gradients.
    static let barTop = LinearGradient(
        colors: [Color(hex: 0xB96FDA), Color(hex: 0xC98A72)],
        startPoint: .leading, endPoint: .trailing
    )

    /// Descending fills for the "All classes" bars below the top class.
    static let barRamp: [Color] = [
        Color(hex: 0x8B4E9E), Color(hex: 0x6B3E86),
        Color(hex: 0x553171), Color(hex: 0x4B2E8F)
    ]

    /// Opaque fill for a *text* control that floats on one of the gradient
    /// surfaces, used when Reduce Transparency turns its glass off.
    ///
    /// The design draws those controls as white washes, which hold over the
    /// gradient's deep end and not over its light one — the wash rides the ramp
    /// up while the white label cannot follow. `white 20%` composited on the
    /// `#7C479B` the sheets' Done capsule actually sits on gives `#9668AF`, and
    /// white on that measures **4.15:1**, under `design/README.md`'s 4.5:1 floor
    /// for body text. This is the gradients' own deepest stop, opaque, so the
    /// ratio no longer depends on where along the ramp the control lands: white
    /// on it measures **10.1:1** everywhere.
    ///
    /// Icon-only chrome on a gradient (Home's hero gear) keeps its white wash —
    /// a glyph answers to the 3:1 non-text floor, which `white 16%` clears at
    /// 4.40:1 on the same header.
    static let gradientControlFill = Color(hex: 0x4B2E8F)

    /// Text on any gradient surface: white, never below 92% opacity.
    static func onGradient(_ opacity: Double = 1) -> Color {
        .white.opacity(max(opacity, 0.92))
    }

    // MARK: Radii
    static let heroCorner: CGFloat = 34
    static let bandCorner: CGFloat = 30
    static let sheetCorner: CGFloat = 30
    static let cardCorner: CGFloat = 18
    static let rowCorner: CGFloat = 16
    static let panelCorner: CGFloat = 20
    static let stageCorner: CGFloat = 24

    // MARK: Spacing
    static let pageMargin: CGFloat = 26
    static let stageInset: CGFloat = 16
    static let spacingXS: CGFloat = 4
    static let spacingS: CGFloat = 10
    static let spacingM: CGFloat = 16
    static let spacingL: CGFloat = 24
    static let spacingXL: CGFloat = 34
    static let rowHeight: CGFloat = 54
    static let minTarget: CGFloat = 44

    /// The design's `line-height: .95` on the 76pt hero numeral.
    static let heroNumeralLineHeight: CGFloat = 76 * 0.95

    /// Bottom padding every scrolling screen adds so its last element clears
    /// the floating tab bar (62 tall, 30 from the bottom edge).
    static let tabBarClearance: CGFloat = 130

    // MARK: Motion
    static let sheetRise = Animation.timingCurve(0.32, 0.72, 0, 1, duration: 0.42)
    static let sweepDuration: Double = 4
    static let pulseDuration: Double = 1.2
}

/// A CSS-style angular linear gradient.
///
/// SwiftUI's `LinearGradient` takes `UnitPoint`s, which are resolved against
/// the box — so a fixed pair of corners yields a different *angle* for every
/// aspect ratio. CSS resolves an angle against the box instead: the gradient
/// line runs through the centre at `degrees` clockwise from straight up, and
/// its length is `|w·sin θ| + |h·cos θ|` so the ramp exactly spans the box.
/// This measures the box and reproduces that, keeping the design's single
/// `152deg` true on the hero, the bands, capsules and the 60pt shutter core
/// alike.
///
/// It is a `View`, not a `ShapeStyle`, because a `ShapeStyle` is resolved
/// without any size to measure. Use it as a `.background { }` with a
/// `.clipShape`, or masked by a shape.
struct OCRGradient: View {
    var stops: [Gradient.Stop]
    var degrees: Double = 152

    var body: some View {
        GeometryReader { proxy in
            let ends = Self.endpoints(degrees: degrees, size: proxy.size)
            LinearGradient(stops: stops, startPoint: ends.start, endPoint: ends.end)
        }
    }

    /// The unit-space endpoints of the CSS gradient line. They intentionally
    /// fall outside 0...1 — that is what makes the ramp cover the corners.
    nonisolated static func endpoints(
        degrees: Double,
        size: CGSize
    ) -> (start: UnitPoint, end: UnitPoint) {
        let w = max(size.width, 0.001)
        let h = max(size.height, 0.001)
        let radians = degrees * .pi / 180
        // Screen space: x right, y down. CSS 0° points up, clockwise positive.
        let dx = sin(radians)
        let dy = -cos(radians)
        let length = abs(w * dx) + abs(h * dy)
        let halfX = dx * length / 2
        let halfY = dy * length / 2
        return (
            UnitPoint(x: (w / 2 - halfX) / w, y: (h / 2 - halfY) / h),
            UnitPoint(x: (w / 2 + halfX) / w, y: (h / 2 + halfY) / h)
        )
    }
}

extension View {
    // The scroll-edge treatment every full-screen tab shares lives with the
    // chrome that motivates it, in `RootView.ocrScrollEdges()`. It supersedes
    // the `ocrFlushTop()` that used to sit here, which hid the edge effect on
    // `.all` edges and so suppressed the bottom one — the one the floating tab
    // bar needs — along with the top.

    /// QA-automation hook (debug builds only): `-qaScrollBottom 1` parks every
    /// scrolling screen at its last element, so a headless sweep can check
    /// that the floating tab bar covers nothing at the end of the page.
    /// Inert in Release and whenever the argument is absent.
    func ocrQAScrollBottom() -> some View {
        #if DEBUG
        defaultScrollAnchor(
            UserDefaults.standard.bool(forKey: "qaScrollBottom") ? .bottom : .top
        )
        #else
        self
        #endif
    }

    /// Trims the 76pt confidence numeral to the design's `line-height: .95`.
    ///
    /// SF Pro's natural line box at 76pt is ~91pt, which pushed the hero panel
    /// ~19pt taller than the measured design and opened a visible gap under
    /// the numeral. The height frame tightens that line box; because it scales
    /// with Dynamic Type the numeral keeps its proportions instead of growing
    /// out of a pinned 72.2pt box and colliding with the lines around it.
    ///
    /// Only the *vertical* size is fixed. A bare `fixedSize()` would propose
    /// `nil × nil` to the `Text`, which hands it its full ideal width and makes
    /// the caller's `minimumScaleFactor` inert — the numeral would then be
    /// clipped by the hero's `clipShape` rather than shrinking. Callers pair
    /// this with `.lineLimit(1).minimumScaleFactor(0.4)`.
    func ocrHeroLineHeight() -> some View {
        modifier(OCRHeroLineHeight())
    }

    /// Paints an `OCRGradient` behind the view, clipped to `shape`.
    func ocrGradientBackground(
        _ gradient: OCRGradient,
        in shape: some Shape
    ) -> some View {
        background { gradient.clipShape(shape) }
    }
}

/// Backs `View.ocrHeroLineHeight()`. It is a `ViewModifier` rather than a plain
/// function so it can hold a `@ScaledMetric` — a `View` extension has nowhere
/// to put dynamic state, which is why the height used to be a fixed constant.
private struct OCRHeroLineHeight: ViewModifier {
    @ScaledMetric(relativeTo: .largeTitle)
    private var lineHeight: CGFloat = Theme.heroNumeralLineHeight

    func body(content: Content) -> some View {
        content
            .fixedSize(horizontal: false, vertical: true)
            .frame(height: lineHeight)
    }
}

/// The one rounding rule for every confidence percentage the app shows.
///
/// `Double.formatted(.percent…)` rounds half-to-even while
/// `Int((p * 100).rounded())` rounds half-away-from-zero, so a probability of
/// exactly 0.125 read "12%" in the Result sheet and "13" in the History row
/// created by the very same scan. Every surface goes through here instead, so
/// one stored probability can only ever render one way.
nonisolated enum ConfidencePercent {
    /// The displayed whole-number percentage, clamped to 0...100.
    static func value(_ probability: Double) -> Int {
        Int((min(max(probability, 0), 1) * 100).rounded())
    }

    /// The same number with its percent sign, e.g. "91%".
    static func text(_ probability: Double) -> String {
        value(probability).formatted(.percent)
    }
}

// `nonisolated` because `Theme` is, and its tokens are built from this
// initializer — `OCRUI` compiles with `defaultIsolation(MainActor)`, which
// would otherwise make this main-actor-isolated and every `Theme` constant
// an isolation error.
nonisolated extension Color {
    /// Builds a color from a packed `0xRRGGBB` literal, so the design's hex
    /// tokens transcribe without conversion.
    init(hex: UInt32) {
        self.init(.sRGB,
                  red: Double((hex >> 16) & 0xFF) / 255,
                  green: Double((hex >> 8) & 0xFF) / 255,
                  blue: Double(hex & 0xFF) / 255,
                  opacity: 1)
    }
}

nonisolated extension RiskLevel {
    /// Short human-readable label, e.g. "Low risk". The restyle renders tiers
    /// as plain text — the old tier-colored `RiskBadge` is gone, so there is
    /// deliberately no color for a tier any more.
    var displayLabel: String {
        switch self {
        case .low: "Low risk"
        case .moderate: "Moderate risk"
        case .high: "High risk"
        }
    }
}

// MARK: - Type
//
// Tracking has no Font-level representation in SwiftUI, so it is applied at
// each call site:
//   Text("91%").font(.ocrHeroNumeral()).tracking(-3.6).monospacedDigit()
//   Text("Scan").font(.ocrScreenTitle()).tracking(-0.7)
//   Text("Earlier scans").font(.ocrSectionHead()).tracking(-0.45)

extension Font {
    static func ocrHeroNumeral() -> Font { .system(size: 76, weight: .semibold) }
    static func ocrScreenTitle() -> Font { .system(size: 26, weight: .semibold) }
    static func ocrSectionHead() -> Font { .system(size: 21, weight: .semibold) }
    static func ocrCardTitle() -> Font { .system(size: 16.5, weight: .semibold) }
    static func ocrRowTitle() -> Font { .system(size: 16, weight: .medium) }
    static func ocrBody() -> Font { .system(size: 14.5) }
    static func ocrMeta() -> Font { .system(size: 13.5) }
    static func ocrSectionLabel() -> Font { .system(size: 13, weight: .semibold) }
    static func ocrFootnote() -> Font { .system(size: 13) }
}
