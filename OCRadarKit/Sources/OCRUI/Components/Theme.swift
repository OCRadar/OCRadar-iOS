import OCRCore
import SwiftUI

/// Design tokens for the app-wide restyle: a dark-only palette, the logo-derived
/// gradients, radii, spacing steps and motion curves. Values are transcribed
/// from `design/README.md`, where every contrast ratio was measured — in
/// particular the third gradient stop must stay at `#96554F`, because at the
/// earlier `#D08A6E` white labels measured 2.8–3.7:1.
///
/// # The ink family
///
/// The handoff's neutral ramp started at `#000000`. Pure black is the one colour
/// every dark app inherits for free, so it reads as un-chosen; the ramp is now a
/// **violet ink** whose hue is pulled from the hero gradient's deep stop
/// (`#4B2E8F`, hue 258°). Every dark surface — canvas, cards, raised chips,
/// dividers, the camera stage, the radar rings — sits at that same hue,
/// 253–260°, so they read as one family rather than a mix of tinted and
/// leftover-neutral planes.
///
/// **The bias is a whisper, not a wash.** The hero indigo is 51% saturated; the
/// ink runs 12–21%, and the greys 8–9%. Against true black the tint is plainly
/// there; on its own it reads as a very dark neutral. A *content* surface that
/// looks purple in a screenshot has overshot and is a bug.
///
/// Saturated purple is spent in four places and nowhere else: the gradient
/// hero and header bands, the newest-scan avatar, the Scan control, and the
/// floating tab bar. The last is the one deliberate exception to the whisper
/// rule — it is chrome rather than content, and it is argued for at
/// `chromeTint`.
///
/// # How the ramp was re-derived
///
/// Lifting the floor from `#000000` (L\* 0) to `#0F0D14` (L\* 4.0) compresses
/// every step above it, because the handoff's spacing assumed a zero floor.
/// Each surface was therefore re-solved at hue 256° for a target CIE **L\***, not
/// picked by eye: `new = 4.0 + 0.85 × old`. The 0.85 keeps the app as dark as it
/// was designed to be while preserving the *order* and near-preserving the size
/// of every plane change (`canvas → surface` 6.0 → 5.1, `surface → divider`
/// 5.5 → 4.9, `surface → surfaceRaised` 9.4 → 7.8). Contrast ratios below are
/// WCAG 2.x relative luminance, computed, not estimated.
///
/// The resulting ladder, darkest first:
/// `stageFill` 2.7 · `canvas` 4.0 · `medicalNoticeFill` 7.5 · `surface` 9.1 ·
/// `stageBorder` 12.7 · `divider` 14.0 · `surfaceRaised` 16.8 ·
/// `radarRing` 16.9 · `noticeBorder` 18.7. The floating chrome sits off this
/// ladder on purpose — see `chromeTint`.
///
/// `medicalNoticeFill` is on the ladder rather than beside it because that is
/// the whole point of the value: the medical notice is red, but it is never
/// *raised*, so it has to sit below `surface` in the same ordering every other
/// plane obeys. See the `medicalNotice…` tokens for the rest of that argument.
nonisolated enum Theme {
    // MARK: Colour — the violet-ink family (hue 253–260°, sat 12–21%)
    //
    // Text ratios are measured against the surfaces text actually lands on.
    // `design/README.md`'s floors still hold: body text ≥ 4.5:1, and
    // `textTertiary` is the lightest colour allowed to carry text.

    static let canvas = Color(hex: 0x0F0D14)          // L* 4.0 — was #000000
    static let surface = Color(hex: 0x1B1823)         // L* 9.1 — cards, list groups
    static let surfaceRaised = Color(hex: 0x2C2737)   // L* 16.8 — chips, tracks, tab pill
    static let divider = Color(hex: 0x25222D)         // L* 14.0 — hairlines inside cards

    static let textPrimary = Color.white              // 19.30:1 canvas · 17.48:1 surface
    /// Body copy, labels, meta. 6.58:1 on `canvas`, 5.96:1 on `surface`,
    /// 4.93:1 on `surfaceRaised` — clears 4.5:1 on every surface in the app.
    static let textSecondary = Color(hex: 0x9A94A6)
    /// Footnotes and the disclaimer; the lightest colour allowed for text.
    /// 5.25:1 on `canvas`, 4.76:1 on `surface`, 5.39:1 on `stageFill` — the
    /// three surfaces it is actually drawn on. Lightened from `#76767E`, which would have fallen
    /// to 4.29:1 / 3.88:1 on the new ramp — under the floor on both.
    /// It is never drawn on `surfaceRaised` (3.93:1) and must not be.
    static let textTertiary = Color(hex: 0x8A8296)
    /// Large numerals on non-highlighted rows. Unchanged — it already carried
    /// the family's faint bias, and it reads everywhere: 14.12:1 on `surface`,
    /// 11.68:1 on `surfaceRaised` (the History avatar), 15.59:1 on `canvas`.
    static let numeralMuted = Color(hex: 0xE8E6EC)
    /// Disclosure chevrons. A non-text control, so the floor is 3:1 — which the
    /// old `#5A5A62` met on black (3.07:1) but *not* on the card it is actually
    /// drawn on (2.71:1 on the old `surface`, and 2.83:1 on the new one).
    /// `#716B7E` measures 3.42:1 on `surface` and 3.77:1 on `canvas`.
    static let chevron = Color(hex: 0x716B7E)

    static let accent = Color(hex: 0xC77BE8)          // 6.18:1 on surface
    static let accentHover = Color(hex: 0xDBA5F0)     // link pressed
    static let salmon = Color(hex: 0xE39B7B)          // data only, never behind text
    static let mint = Color(hex: 0x5FD3A6)            // live-model indicator

    /// Camera stage. The one surface deliberately taken *below* `canvas`
    /// (L\* 2.7 vs 4.0) rather than up the ladder: `ScanView` uses it at 50%
    /// as the glass tint over the live frame, where every unit of darkness is
    /// legibility. Held against a bright review frame the tint composites a
    /// hair *darker* than `#0C0C0F` did, so `ScanView`'s measured pill and
    /// capsule ratios are preserved, not eroded. The stage now reads as a well
    /// cut into the page instead of a panel raised off it.
    static let stageFill = Color(hex: 0x0B0910)
    static let stageBorder = Color(hex: 0x231F2C)     // L* 12.7 — 10.0 above stageFill
    static let radarRing = Color(hex: 0x2C2738)       // L* 16.9 — matches surfaceRaised

    /// Outline of the demo notice card — a hair above `divider` so the card
    /// reads as outlined rather than filled.
    static let noticeBorder = Color(hex: 0x302B3B)

    // MARK: Medical notice — the one red object in the app
    //
    // These three back `OCRMedicalNotice` and nothing else. They are deliberately
    // *not* named `noticeInk` / `noticeFill`: `noticeBorder` above is already
    // taken by the demo-mode notice card's grey outline, and a red `noticeInk`
    // sitting beside a grey `noticeBorder` would read as one set of tokens for
    // one component. The `medicalNotice` prefix keeps the two apart.
    //
    // # Why red is safe here
    //
    // The restyle removed tier colour entirely — `RiskLevel.displayLabel` renders
    // "Routine" / "Worth asking about" / "See a professional soon" as plain text
    // in the ambient ink colours, and there is no `Theme` colour for a tier (see
    // the note on `RiskLevel.displayLabel`). So red is not spoken anywhere in the
    // app, and the medical notice can claim it outright without a low-risk result
    // inheriting an alarm colour it did not earn.
    //
    // That claim has to survive a tier palette coming back. It does, because the
    // notice is separated from a tier by **form**, not by hue: a tier is inline
    // text inside a sentence, and the notice is a bordered rectangle with a
    // warning glyph and a fixed title. Should a high-risk red ever be introduced,
    // it must be a *text* colour only — never a border, never a fill — so the two
    // stay distinguishable at a glance even to a reader who cannot separate them
    // by hue at all.
    //
    // # The family
    //
    // Hue is locked to the hero gradient's warm stop (`#96554F`, hue 5.1°), so
    // the notice is the app's own red rather than the system's `#FF3B30`
    // (hue 3.2°) bolted on. Saturation and lightness are then solved for the
    // contrast floors, not picked by eye. All ratios are WCAG 2.x, computed
    // against the surfaces the notice is actually drawn on.

    /// Notice title and warning glyph. Hue 5.0° — the warm stop's hue at full
    /// saturation, lifted to L\* 66.8 until it clears the 4.5:1 body floor on
    /// every ground it can land on.
    ///
    /// **7.59:1** on `canvas` · **6.88:1** on `surface` · **7.08:1** on
    /// `medicalNoticeFill` · 7.24:1 on the disclaimer sheet's `#15131C` ·
    /// 5.69:1 on `surfaceRaised` · 7.35:1 / 6.64:1 on canvas and surface under
    /// the worst case of `bloom`.
    ///
    /// A saturated `#FF3B30` was measured first and rejected: 5.44:1 on
    /// `canvas` but **4.93:1** on `surface`, which clears the floor by 0.43 —
    /// no margin at all for the bloom, and it fails outright on
    /// `surfaceRaised` (3.55:1). This is that red lightened until every ground
    /// in the app has room to spare.
    static let medicalNoticeInk = Color(hex: 0xFF7A6E)

    /// The notice's 1.5pt border. A non-text element, so the floor is 3:1, and
    /// it is the outline that has to carry the object when the fill is nearly
    /// invisible — as it is when the notice sits on a `surface` card.
    ///
    /// **4.31:1** on `canvas` · **3.91:1** on `surface` · **4.02:1** against
    /// `medicalNoticeFill` on the inside · 3.23:1 on `surfaceRaised` ·
    /// 4.18:1 / 3.77:1 under `bloom`.
    ///
    /// The ink taken down to L\* 50.1 with saturation pulled back to 49.6% —
    /// between the warm stop's 31% and the ink's 100%. Full saturation at this
    /// lightness reads as a drawn line rather than an edge; the warm stop's own
    /// saturation reads as brown.
    static let medicalNoticeBorder = Color(hex: 0xC2554A)

    /// The notice's background wash. `medicalNoticeInk` at **6% over `canvas`**,
    /// resolved to an opaque value the way `chromeFill` resolves the tab bar's
    /// glass — so the wash cannot ride up whatever it happens to be stacked on,
    /// and so nothing here depends on a material that Reduce Transparency turns
    /// off.
    ///
    /// L\* **7.51**, which is the load-bearing number: `surface` is L\* 9.05, so
    /// the notice is always *darker* than a card and can never read as one
    /// raised off the page. Against `canvas` (L\* 3.97) it is a clear plane
    /// change; against a `surface` card it is a whisper (1.03:1) and the border
    /// does the work, which is the intended division of labour.
    ///
    /// The notice sets its body in `textPrimary`, which measures **18.01:1**
    /// here, and its title and glyph in `medicalNoticeInk` at **7.08:1**. The
    /// fainter inks are recorded only as headroom, since nothing draws on this
    /// fill but `OCRMedicalNotice`: `textSecondary` 6.14:1, `textTertiary`
    /// 4.90:1 — both still over the 4.5:1 floor.
    ///
    /// It resolves to hue 327° rather than the family's 5°, because a 6% red
    /// wash cannot outvote the violet ink's own blue channel at this darkness.
    /// That is correct: at L\* 7.5 the hue is not perceptible as either red or
    /// violet, and forcing it to 5° by draining the blue would take the one
    /// surface in the app that is *supposed* to belong to both families and
    /// make it the only near-neutral plane on the page.
    static let medicalNoticeFill = Color(hex: 0x1D1419)

    // MARK: Signature — the three tokens that carry the hero's language outward.
    //
    // The hero panel is the best thing in the app; these exist so the rest of it
    // can speak the same language without repeating the gradient. All three are
    // deliberately below the threshold of "an effect you can point at" — if a
    // first-time user can name one of them, it is turned up too far.

    /// A lit hairline for the top edge of a card, so a surface reads as a
    /// tilted plane catching light rather than an untreated flat rectangle.
    ///
    /// White at 7%: `+7.7` L\* over `surface`, `+6.9` over `surfaceRaised` —
    /// about one rung of the ink ladder, which is exactly a hairline's worth.
    /// Draw it as a 1px stroke or a top-aligned gradient stop, never as a full
    /// border; a closed outline reads as system chrome, which is the enemy.
    static let surfaceEdge = Color.white.opacity(0.07)

    /// Optional film-grain overlay. White at 2% — at full strength one grain
    /// speck lifts `canvas` by `1.9` L\*, so the texture registers as tooth on
    /// the ink rather than as visible noise. Apply with `.blendMode(.plusLighter)`
    /// over large flat fields only, and never over text.
    static let grain = Color.white.opacity(0.02)

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

    /// Ambient glow behind a screen's content: the hero's deep indigo, radiating
    /// from just off the top edge and gone before it reaches the bottom. It is
    /// how a screen without a gradient panel still feels lit by the same source
    /// as the ones that have one.
    ///
    /// Peak is 9% — over `canvas` that lands at L\* 5.6, which is *below*
    /// `surface` (9.1), so a card never dissolves into the glow it sits in. Text
    /// survives the worst case, a card centred under the peak: `textSecondary`
    /// 5.76:1 and `textTertiary` 4.59:1 on the bloomed `surface`, both still
    /// over the 4.5:1 floor.
    ///
    /// A fixed `endRadius` rather than a relative one, so the falloff is the
    /// same physical size on a tall scroll view and a short sheet instead of
    /// stretching with the frame. Use it as a full-bleed `.background`.
    static let bloom = RadialGradient(
        stops: [
            .init(color: Color(hex: 0x4B2E8F).opacity(0.09), location: 0),
            .init(color: Color(hex: 0x4B2E8F).opacity(0.035), location: 0.5),
            .init(color: Color(hex: 0x4B2E8F).opacity(0), location: 1)
        ],
        center: UnitPoint(x: 0.5, y: 0.04),
        startRadius: 0,
        endRadius: 460
    )

    /// Fill of the Result sheet's top-class bar only. Horizontal, unlike the
    /// diagonal surface gradients.
    static let barTop = LinearGradient(
        colors: [Color(hex: 0xB96FDA), Color(hex: 0xC98A72)],
        startPoint: .leading, endPoint: .trailing
    )

    /// Descending fills for the similarity-ranking bars below the top class.
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

    // MARK: Chrome — the floating tab bar's two glass surfaces.
    //
    // These are the one place the ink family is deliberately pushed past a
    // whisper of violet into an actual purple, because the tab bar is chrome,
    // not a content surface: it floats over the page rather than carrying it,
    // so it is read as an object in its own right and a neutral one reads as
    // the system's, not the app's.
    //
    // The values are picked for what the *material resolves to*, not for how
    // they look as swatches. Regular glass contributes a large near-neutral
    // lift — measured at roughly `#3A3642` on this app's canvas — so the tint
    // must be far more saturated than the intended result. Composited, a 60%
    // `chromeTint` lands at about `#2D2549` (hue 258°, saturation 49%) where
    // the ink family's own near-neutral landed at `#292531` (saturation 24%, and
    // plainly grey on screen). Same hue as the ink family; enough chroma to
    // read as chosen.

    /// Glass tint for the navigation pill (Settings · Home · History), used at
    /// 60%. Resolves to roughly `#2D2549`.
    static let chromeTint = Color(hex: 0x241A4E)

    /// Flat fill the navigation pill returns to under Reduce Transparency —
    /// the value the glass resolves to, so turning the setting on changes the
    /// material without changing the colour the user learned.
    static let chromeFill = Color(hex: 0x2D2549)

    // The Scan circle needs no token of its own: it is a solid `Theme.button`
    // gradient disc, the same fill as the shutter. See `OCRTabBar.scanButton`
    // for why the chrome's action surface is deliberately not glass.

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
    /// The tier as **next-step guidance**, e.g. "Worth asking about".
    ///
    /// # Why these are actions and not severities
    ///
    /// These used to read "Low risk" / "Moderate risk" / "High risk". That is a
    /// health assertion: it tells a reader how sick they are, which is a claim
    /// this app cannot make and does not have the evidence to make. The app
    /// compares an image to reference categories; it does not know what anyone
    /// has. So the label says what to *do* instead, which is the one thing the
    /// comparison can honestly support.
    ///
    /// Do not revert these to severity words, and do not add "risk" back to
    /// them. The tier is guidance; `RiskLevel`'s own doc comment says the same
    /// thing at the source.
    ///
    /// Rendered as plain text — the old tier-colored `RiskBadge` is gone, so
    /// there is deliberately no color for a tier any more (see
    /// `Theme.medicalNoticeInk` for why that matters). Never abbreviated or
    /// truncated: layouts wrap or stack instead.
    var displayLabel: String {
        switch self {
        case .low: "Routine"
        case .moderate: "Worth asking about"
        case .high: "See a professional soon"
        }
    }

    /// The same guidance as one plain sentence, for detail contexts that have
    /// room for it — the result sheet and the scan-detail panel, where the
    /// terse label alone leaves a reader asking "so what do I do?".
    ///
    /// Same rule as `displayLabel`: it says what to do next, never what a
    /// finding is. Rows and compact meta lines use `displayLabel`; this is not
    /// a replacement for it.
    var guidanceDetail: String {
        switch self {
        case .low: "Mention it at your next dental visit if it doesn't clear up."
        case .moderate: "Worth bringing to a dentist or doctor the next time you see one."
        case .high: "Book a visit with a dentist or doctor in the next few days."
        }
    }
}

// MARK: - Type
//
// The type scale lives in `OCRType.swift`, as `OCRTextStyle` + `.ocrFont(_:)`.
