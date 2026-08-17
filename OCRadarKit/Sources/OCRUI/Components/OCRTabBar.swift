import SwiftUI

/// The app's floating navigation chrome: **two** surfaces side by side rather
/// than one bar — a glass pill for navigation, a solid gradient circle for the
/// one action.
///
/// ```
/// [  ⚙︎    ⌂    ◷  ]   ( ⃝ )
/// ```
///
/// A capsule **pill** on the leading side carries Settings · Home · History and
/// takes the remaining width; a **circle** on the trailing side carries Scan
/// alone at the pill's own height, so the two read as a matched set — one
/// navigation object and one action object — instead of four equal peers. The
/// outer geometry is unchanged from the single-bar version and from
/// `design/README.md`: 62 tall, inset 14 from each screen edge, 30 up from the
/// bottom of the screen. Screens still clear it with `Theme.tabBarClearance`.
///
/// Screens extend *under* it, so `RootView` overlays it on a bottom-aligned
/// `ZStack` rather than reserving a safe-area inset, and it owns its own insets
/// so callers add no padding around it.
///
/// **Icons only.** The 10pt text labels are gone; the glyphs grow to ~23pt and
/// centre in their slot. Every item is still a real `Button` carrying its
/// `.accessibilityLabel` and, when current, the `.isSelected` trait — dropping
/// the *visible* label must not drop the *spoken* one, and it does not.
///
/// **One family of glyphs.** All four are filled SF Symbols at one weight and
/// one optical size. That is why History is `clock.fill` and Scan is
/// `camera.fill` rather than the handoff's `clock.arrow.circlepath` and
/// `camera.viewfinder`: those two are outline-only, and setting them beside
/// `house.fill` and `gearshape.fill` put two stroke weights in a 4-glyph row —
/// the single loudest "assembled from defaults" tell in the old bar.
/// `camera.fill` is itself already in `design/README.md`'s symbol table.
///
/// See `OCRGlass.swift` for the tint and Reduce Transparency rules the pill
/// follows.
struct OCRTabBar: View {
    @Binding var selection: AppTab

    @Environment(\.accessibilityReduceTransparency) private var reduceTransparency
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    /// Shared by the pill's glass surface (`glassEffectID`) and by its selection
    /// chip (`matchedGeometryEffect`). The two mechanisms use disjoint ID types
    /// — `Surface` and `AppTab` — so they cannot collide.
    @Namespace private var chrome

    /// Glyph size.
    ///
    /// The design's 23, scaled — and the *scaling* is what is capped rather
    /// than the number. An earlier note here had this the other way round: it
    /// claimed `Font.system(size:)` was already scaled by SwiftUI and made the
    /// size a bare constant on that basis. It is not (see `OCRTextStyle`), so
    /// the constant meant the clamp below governed nothing and the bar was the
    /// one piece of chrome that never answered Dynamic Type at all.
    ///
    /// The glyph now grows through `.ocrFont`, and `dynamicTypeSize(...)` —
    /// written *outside* it, so it reaches the scaled metric inside — is what
    /// stops it. The bar is icons-only and every item still carries its spoken
    /// label, so nothing here is text a low-vision user reads; clamping at
    /// `.xLarge` keeps a real response (23 → ~25.7pt) while guaranteeing the
    /// glyph stays inside the 50pt slot.
    private static let iconPoint: CGFloat = 23

    /// The ceiling on that response. `.xLarge` is the largest step whose body
    /// ratio (19/17) keeps the glyph under the 27pt the fixed chrome allows;
    /// `.xxLarge` (21/17) would put it at 28.4.
    private static let iconTypeCeiling: DynamicTypeSize = .xLarge

    /// Identifies the glass surface to the container. Only the pill is glass —
    /// see `scanButton` for why the Scan circle is a solid gradient — but the
    /// ID stays explicit so the container can never adopt some other view as
    /// its morph target.
    /// `nonisolated` because `OCRUI` compiles with `defaultIsolation(MainActor)`:
    /// a main-actor-isolated `Hashable` conformance cannot satisfy
    /// `glassEffectID`'s `Sendable` requirement on its ID.
    private nonisolated enum Surface: Hashable { case pill }

    private struct Item: Identifiable {
        let tab: AppTab
        let symbol: String
        let label: String
        var id: AppTab { tab }
    }

    /// Settings · Home · History, in that order. Home sits in the middle so the
    /// default destination is under the thumb's centre and the two
    /// less-travelled tabs flank it.
    private let pillItems: [Item] = [
        .init(tab: .settings, symbol: "gearshape.fill", label: "Settings"),
        .init(tab: .home, symbol: "house.fill", label: "Home"),
        .init(tab: .history, symbol: "clock.fill", label: "History")
    ]

    private let scanItem = Item(tab: .scan, symbol: "camera.fill", label: "Scan")

    // MARK: Geometry

    /// Height of the pill *and* diameter of the circle — one number, because
    /// the moment they differ the pair stops reading as a set.
    private static let surfaceHeight: CGFloat = 62
    /// Gap between the two surfaces. Also the ceiling on the container's
    /// blending distance; see `body`.
    private static let surfaceGap: CGFloat = 11
    /// Design's inner pill height. Each slot is ~90pt wide on the narrowest
    /// supported screen, so every item clears the 44×44 minimum comfortably.
    private static let slotHeight: CGFloat = 50

    // MARK: Material

    /// Tint for the navigation pill: `Theme.chromeTint` at 60%.
    ///
    /// An earlier version tinted with the ink family's own near-neutral
    /// (`#1E1A26`) — on the reasoning that the violet would
    /// register against the canvas. Sampled off a device screenshot it did not:
    /// regular glass adds a large near-neutral lift, and the surface resolved to
    /// `#292531`, saturation 24%, which reads plainly grey next to a `#0F0D14`
    /// canvas. `chromeTint` is the same hue with enough chroma to survive that
    /// lift, resolving to about `#2D2549` at saturation 49%.
    ///
    /// The 60% is unchanged and still earns its place: it darkens the resting
    /// surface and damps how far content scrolling underneath can push it, while
    /// staying well short of the opacity at which the bar stops refracting and
    /// starts reading as a solid slab. Measured on the four tabs the pill holds
    /// `#2D2549`–`#292244`, saturation 49–50% throughout, so the material moves
    /// with its backdrop by about a rung of the ink ladder and no more — which
    /// is what glass is supposed to do. The bar is icons-only, so its glyphs
    /// answer to the 3:1 non-text floor; unselected `Theme.textSecondary`
    /// computes 4.86:1 on the resting surface, clear either way.
    private var pillTint: Color { Theme.chromeTint.opacity(0.6) }


    /// Fill of the selected item's chip — a **neutral** light, never a second
    /// patch of accent. Selection here means elevation, not emphasis; accent is
    /// spent once, on Scan.
    ///
    /// The design's selected pill is `surfaceRaised`, one step *lighter* than
    /// the bar. That holds as a fixed colour only while the bar is a fixed
    /// colour. On glass the bar moves: untinted it sampled `#363438`, lighter
    /// than `#26262C`, so the selected tab read as a dark hole punched in the
    /// bar rather than a raised chip — the hierarchy inverted. A white overlay
    /// keeps the relationship the design describes: a step above whatever the
    /// material is doing.
    ///
    /// 12%, not the 10% the brief sketches, because the new violet-ink canvas
    /// resolves the bar *lighter* than the old true-black one did (about
    /// `#2B2732` against the old `#212125`); the same white step therefore buys
    /// less separation than before, and dropping to 10% would spend the rest of
    /// it. At 12% the chip computes to about `#403D46`, with white on it at
    /// 10.6:1 and the Scan accent at 3.8:1 — both clear.
    ///
    /// That reasoning only applies while there *is* a material. With Reduce
    /// Transparency on, both surfaces return to their flat chrome tokens, so
    /// the chip returns to the flat `surfaceRaised` token it was drawn as — the
    /// same contract every surface in `OCRGlass.swift` keeps. Left as the white
    /// overlay it composited to roughly `#323235` and the design token was
    /// silently lost in the accessibility path.
    private var selectedChipFill: AnyShapeStyle {
        reduceTransparency
            ? AnyShapeStyle(Theme.surfaceRaised)
            : AnyShapeStyle(.white.opacity(0.12))
    }

    /// The ink family continued one rung *below* `Theme.stageFill`, rather than
    /// the pure black the chrome used to drop. A shadow is absence of light and
    /// so must go darker than `canvas`, but there is no reason for the one dark
    /// value the app paints to be the one neutral it deliberately abandoned.
    private static let shadowInk = Color(hex: 0x07050D)

    var body: some View {
        // The container wraps **only** the pill, because only the pill is glass;
        // the Scan circle is a solid gradient and has nothing to blend with.
        // Geometry is unaffected — the `HStack` and its `surfaceGap` own the
        // layout either way.
        //
        // `spacing: 0` is the distance within which glass shapes *fuse*. With a
        // single child nothing can fuse, but it stays explicit so adding a
        // second glass surface later cannot silently merge the two.
        HStack(spacing: Self.surfaceGap) {
            GlassEffectContainer(spacing: 0) {
                pill
            }
            scanButton
        }
        .padding(.horizontal, 14)
        .padding(.bottom, 30)
        // The design measures the 30pt inset from the bottom of the *screen*,
        // not from the home-indicator safe area. Without this the bar floated
        // 64 up instead of 30 and the whole layout read short.
        .ignoresSafeArea(.container, edges: .bottom)
    }

    // MARK: - The pill

    private var pill: some View {
        HStack(spacing: 0) {
            ForEach(pillItems) { item in
                pillItem(item)
            }
        }
        .padding(.horizontal, 6)
        // The selection chip is drawn **once**, here, and borrows its frame
        // from whichever item is current — rather than being drawn inside each
        // item and matched across a removal/insertion pair.
        //
        // That is what makes the Scan case safe. When Scan is selected there is
        // no current pill item, `selectedPillTab` is `nil`, and the single chip
        // is simply removed: it fades out where it stood. There is no second
        // source to inherit a stale frame from, and no anchor anywhere outside
        // this `HStack`, so it is structurally impossible for the highlight to
        // stick on the last tab or to slide across the gap toward the circle.
        // Coming back from Scan it fades in already at the right slot.
        .background {
            if let tab = selectedPillTab {
                Capsule()
                    .fill(selectedChipFill)
                    .matchedGeometryEffect(id: tab, in: chrome, isSource: false)
            }
        }
        .frame(maxWidth: .infinity)
        .frame(height: Self.surfaceHeight)
        .ocrGlass(
            .capsule,
            tint: pillTint,
            fallback: Theme.chromeFill,
            reduceTransparency: reduceTransparency
        )
        .glassEffectID(Surface.pill, in: chrome)
        .shadow(color: Self.shadowInk.opacity(0.6), radius: 15, y: 10)
    }

    /// The tab the chip should currently sit under, or `nil` while Scan — which
    /// lives outside the pill — is selected.
    private var selectedPillTab: AppTab? {
        pillItems.first { $0.tab == selection }?.tab
    }

    private func pillItem(_ item: Item) -> some View {
        let isSelected = selection == item.tab
        return Button {
            select(item.tab)
        } label: {
            glyph(item.symbol)
                .foregroundStyle(isSelected ? Theme.textPrimary : Theme.textSecondary)
                .frame(maxWidth: .infinity, minHeight: Self.slotHeight)
                // Publishes this slot's rect for the chip above to adopt.
                // `isSource: true` only shares the frame; it never resizes the
                // glyph, because nothing else claims this ID as a source.
                .matchedGeometryEffect(id: item.tab, in: chrome, isSource: true)
                .contentShape(.capsule)
        }
        .buttonStyle(.plain)
        .accessibilityLabel(item.label)
        .accessibilityAddTraits(isSelected ? [.isButton, .isSelected] : .isButton)
    }

    // MARK: - The Scan circle

    /// The chrome's one action object: a `Theme.button` gradient disc with a
    /// white glyph, beside a pill of navigation.
    ///
    /// **It is the only surface here that is not glass, and that is the point.**
    /// An earlier version made it a near-neutral glass disc matching the pill,
    /// spending accent only on the glyph and a hairline, on the reasoning that a
    /// filled disc would be "a purple blob at the busiest corner". On screen the
    /// cost was the opposite failure: it read as a fourth peer that happened to
    /// have a coloured icon, and nothing about it said *primary*.
    ///
    /// Filling it is not a new idiom. `design/README.md` already draws the
    /// shutter as a `buttonGradient` circle, and every filled button in the app
    /// is white-on-`buttonGradient`; this is that same object, tab-bar sized, so
    /// the control that starts a scan looks like the control that takes the
    /// photo. It also makes the pair read as what it actually is — a translucent
    /// navigation surface and a solid action — rather than as two tints of one
    /// material. Measured across all four tabs the disc holds `#7C4891`,
    /// where the glass version drifted with whatever the backdrop happened to be.
    ///
    /// White on the gradient measures ≥5.6:1 per `design/README.md`, far above
    /// the 3:1 floor a glyph answers to. Selection is stated in the same
    /// language as the pill — the white chip, here a full disc — plus a step up
    /// in the edge's alpha, so one rule for "current" covers both surfaces.
    private var scanButton: some View {
        let isSelected = selection == .scan
        return Button {
            select(.scan)
        } label: {
            glyph(scanItem.symbol)
                .foregroundStyle(Theme.textPrimary)
                .frame(width: Self.surfaceHeight, height: Self.surfaceHeight)
                .ocrGradientBackground(Theme.button, in: Circle())
                .overlay {
                    if isSelected {
                        Circle().fill(selectedChipFill)
                    }
                }
                .overlay {
                    Circle()
                        .strokeBorder(
                            Color.white.opacity(isSelected ? 0.34 : 0.18),
                            lineWidth: 1
                        )
                }
                .contentShape(.circle)
        }
        .buttonStyle(.plain)
        .shadow(color: Self.shadowInk.opacity(0.6), radius: 15, y: 10)
        .accessibilityLabel(scanItem.label)
        .accessibilityAddTraits(isSelected ? [.isButton, .isSelected] : .isButton)
    }

    // MARK: - Shared

    private func glyph(_ symbol: String) -> some View {
        Image(systemName: symbol)
            // Monochrome explicitly: a couple of these symbols carry a
            // hierarchical default, which would put two glyph densities in a
            // row that exists to look like one set.
            .symbolRenderingMode(.monochrome)
            .ocrFont(.rowTitle.size(Self.iconPoint).weight(.medium))
            .dynamicTypeSize(...Self.iconTypeCeiling)
    }

    /// The single place selection changes, so the chip's move, its fade-out
    /// into the Scan case and its fade back in are all carried by one
    /// transaction — and so Reduce Motion is honoured once rather than at three
    /// call sites. With the setting on, the chip snaps; it never simply stops
    /// updating.
    private func select(_ tab: AppTab) {
        withAnimation(reduceMotion ? nil : .snappy) {
            selection = tab
        }
    }
}

#Preview("Tab bar — interactive") {
    @Previewable @State var selection = AppTab.home

    ZStack(alignment: .bottom) {
        Theme.canvas
        Theme.bloom
        OCRTabBar(selection: $selection)
    }
    .ignoresSafeArea()
    .preferredColorScheme(.dark)
}

#Preview("Tab bar — every tab") {
    ZStack {
        Theme.canvas
        Theme.bloom
        VStack(spacing: 0) {
            ForEach([AppTab.settings, .home, .history, .scan], id: \.self) { tab in
                OCRTabBar(selection: .constant(tab))
            }
        }
    }
    .ignoresSafeArea()
    .preferredColorScheme(.dark)
}
