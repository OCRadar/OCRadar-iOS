import SwiftUI

/// The lit ink every screen sits on, and the two light behaviours the rest of
/// the app borrows from the Home hero.
///
/// The hero panel is the one surface that reads as *lit* — a gradient with a
/// light source somewhere above the top-right corner. Every other screen used
/// to be a flat fill, which is why they read as inherited rather than authored.
/// The three things in this file give those screens the same light without
/// repeating the gradient:
///
/// - `OCRAmbientBackground` — canvas + `Theme.bloom` + optional grain.
/// - `View.ocrPanelSpill()` — a gradient panel bleeding light onto the ink
///   below it instead of ending at a cut edge.
/// - `View.ocrTopEdgeHighlight(_:)` — a hairline of that light caught on the
///   top edge of a surface.
///
/// All three are deliberately below the threshold of an effect a first-time
/// user could point at. If one of them is *nameable* in a screenshot it is
/// turned up too far.

/// The background every full-screen surface uses in place of a bare
/// `Theme.canvas`.
///
/// Three layers, cheapest first:
///
/// 1. `fill` — the violet ink floor, `Theme.canvas` unless a surface that
///    floats above the canvas passes its own (the disclaimer sheet does).
/// 2. `Theme.bloom` — the hero's deep indigo radiating from just off the top
///    edge. `Theme.bloom` fixes its own `endRadius`, so the falloff is the same
///    physical size on a tall scrolling tab and a short sheet.
/// 3. `OCRGrain` — an optional dusting of `Theme.grain` (white at 2%) in
///    `.plusLighter`, which is what keeps the bloom from banding into visible
///    rings on an 8-bit panel, and gives the ink a tooth.
///
/// **It never redraws.** The grain positions are a `static let` derived once
/// from a fixed seed, so the `Canvas` renderer is a pure function of its size —
/// no per-frame randomness, nothing to invalidate while a scroll view moves
/// over it.
///
/// **`compositingGroup()`, deliberately not `drawingGroup()`.** The group is
/// what guarantees the grain's `.plusLighter` adds itself to the canvas and
/// bloom rather than to whatever is behind the window. `drawingGroup()` would
/// also do that, but by rasterizing a full-screen Metal texture — and this view
/// is instantiated up to three deep at once (the root plane, the screen on top
/// of it, a presented sheet on top of that), which is ~12MB of offscreen buffer
/// each on a 3× phone. There is nothing to flatten that would pay for it: the
/// three layers are a solid fill, one gradient and one cached `Canvas`.
///
/// Purely decorative, hidden from VoiceOver and transparent to hit testing, so
/// dropping it behind a screen cannot capture a tap the screen wanted.
struct OCRAmbientBackground: View {
    /// The floor the bloom and the grain are laid over. `Theme.canvas` for every
    /// full-screen tab; the disclaimer sheet passes its own raised fill, because
    /// that sheet floats *above* the canvas and painting it at canvas level
    /// would flatten the one relationship its colour exists to state.
    var fill: Color = Theme.canvas

    /// Turn the grain off for a surface small enough that the tooth would read
    /// as noise rather than texture.
    var grain: Bool = true

    var body: some View {
        ZStack {
            fill
            Theme.bloom
            if grain {
                OCRGrain()
                    // Additive, per `Theme.grain`'s contract: each speck lifts
                    // the ink beneath it by ~1.9 L*, never darkens it.
                    .blendMode(.plusLighter)
            }
        }
        .compositingGroup()
        .ignoresSafeArea()
        .allowsHitTesting(false)
        .accessibilityHidden(true)
    }
}

/// The grain layer. Separate from `OCRAmbientBackground` so the `Canvas` has
/// its own identity and is not rebuilt when the flag around it changes.
private struct OCRGrain: View {
    /// Screen area, in points, that gets one speck. At 64 the mean spacing is
    /// ~8pt: dense enough to read as tooth on the ink, sparse enough that the
    /// whole layer is one `Path` of a few thousand 1pt rects.
    private static let areaPerSpeck: CGFloat = 64

    var body: some View {
        // `rendersAsynchronously: false` — the renderer is microseconds of
        // rect-appending, and a background has nothing to gain from being a
        // frame late.
        Canvas(opaque: false, rendersAsynchronously: false) { context, size in
            let wanted = Int(size.width * size.height / Self.areaPerSpeck)
            let points = OCRGrainField.unitPoints.prefix(
                min(wanted, OCRGrainField.unitPoints.count)
            )
            // One path, one fill: the speck count is high enough that a fill
            // per speck would be the expensive part of this view.
            var path = Path()
            for point in points {
                path.addRect(
                    CGRect(
                        x: point.x * size.width,
                        y: point.y * size.height,
                        width: 1,
                        height: 1
                    )
                )
            }
            context.fill(path, with: .color(Theme.grain))
        }
    }
}

/// Speck positions in unit space, generated once from a fixed seed.
///
/// `nonisolated` so the `Canvas` renderer — which SwiftUI hands out without
/// isolation — can read it, matching how `Theme` and `OCRGlassBackground` are
/// declared in this package.
///
/// Taking a *prefix* sized by the host's area, rather than scaling the whole
/// set, is what keeps the grain the same density on a 844pt tab and on the
/// 582pt disclaimer sheet. Scaling the set would have made the small surface
/// visibly grainier than the large one.
private nonisolated enum OCRGrainField {
    /// Enough for a full-screen surface on the largest iPhone with headroom
    /// (a 440×956 screen wants ~6570).
    private static let capacity = 7000

    static let unitPoints: [CGPoint] = makePoints(count: capacity)

    /// SplitMix64 — a fixed seed in, the same field of specks out, on every
    /// launch and every device. The seed is the hero gradient's deep stop,
    /// which is the same place the bloom's colour comes from.
    private static func makePoints(count: Int) -> [CGPoint] {
        var state: UInt64 = 0x4B2E_8F00_4B2E_8F00
        func nextUnit() -> CGFloat {
            state &+= 0x9E37_79B9_7F4A_7C15
            var z = state
            z = (z ^ (z >> 30)) &* 0xBF58_476D_1CE4_E5B9
            z = (z ^ (z >> 27)) &* 0x94D0_49BB_1331_11EB
            z ^= (z >> 31)
            return CGFloat(Double(z >> 11) * (1.0 / 9_007_199_254_740_992.0))
        }
        return (0..<count).map { _ in
            CGPoint(x: nextUnit(), y: nextUnit())
        }
    }
}

extension View {
    /// A gradient panel spilling a little of its own light onto the ink below,
    /// so it reads as lit rather than pasted on.
    ///
    /// A header band used to end at a hard chromatic cut — the gradient's light
    /// salmon stop butted straight against the ink — which is the single most
    /// "pasted on" edge in the app. This lays a short fall-off of the
    /// gradient's *deep* stop `#4B2E8F` (the same source as `Theme.bloom`)
    /// under the panel's bottom edge. It is a glow, not a shadow: that colour
    /// is lighter than `Theme.canvas`, and a drop shadow on near-black ink
    /// would be invisible anyway.
    ///
    /// **An underlay, not a `shadow()` or a `blur()`.** Those are filters on
    /// the panel's whole subtree, and `OCRSheetHeader`'s subtree contains a
    /// Liquid Glass capsule whose backdrop sampling a filter can disturb. A
    /// plain gradient sibling cannot touch it, costs no offscreen pass, and
    /// gives exact control over where the fall-off starts and ends.
    ///
    /// Geometry: 64 tall, aligned to the panel's bottom and pushed down 36, so
    /// **28pt sit behind the panel** and 36 show below it. The 28 is more than
    /// any panel's corner radius (30/34 curve *up* from the bottom edge), which
    /// is what keeps the gradient's own top edge hidden under the opaque fill
    /// instead of showing as a step beside the rounded corners.
    ///
    /// Intensity: **12%**, and that ceiling is not a taste call. `Theme.bloom`
    /// is capped so its peak stays below `Theme.surface`, because a card that
    /// is darker than the glow it sits in reads as a hole rather than a card.
    /// The spill has to honour the same invariant — a card can land within
    /// 36pt of a header — and it is measured against the *worst* case, a card
    /// directly under a panel that is itself under the bloom's own peak:
    ///
    /// | indigo | peak L\* (spill over bloom over canvas) | vs `surface` 9.05 |
    /// | --- | --- | --- |
    /// | 12% | 8.26 | −0.79 ✓ |
    /// | 16% | 9.15 | +0.10 ✗ inverted |
    /// | 24% | 10.86 | +1.81 ✗ inverted |
    ///
    /// So the first draft's 24% was a bug, not a strong effect. At 12% the
    /// spill still lifts plain canvas by 2.3 L\* — a broad, smooth step that
    /// reads plainly as a soft seam — and text over it holds: `textSecondary`
    /// 6.05:1, `textTertiary` 4.83:1, both over the 4.5 floor. (In practice
    /// there is more headroom than the table shows: the bloom has fallen to
    /// ~5% by the depth a band's bottom edge actually sits at.)
    ///
    /// Where the margin does get thin, `ocrTopEdgeHighlight` is what carries
    /// the card: its hairline is +7.7 L\* over the fill, so the card's top edge
    /// stays legible against the spill even when the fills nearly match.
    ///
    /// Apply it *after* the panel's `clipShape`, so the spill is not trimmed
    /// by it. Decorative and inert.
    func ocrPanelSpill() -> some View {
        let height: CGFloat = 64
        let behind: CGFloat = 28
        let light = Color(hex: 0x4B2E8F).opacity(0.12)
        return background(alignment: .bottom) {
            LinearGradient(
                stops: [
                    .init(color: light, location: 0),
                    .init(color: light, location: behind / height),
                    .init(color: light.opacity(0), location: 1)
                ],
                startPoint: .top,
                endPoint: .bottom
            )
            .frame(height: height)
            .offset(y: height - behind)
            .allowsHitTesting(false)
            .accessibilityHidden(true)
        }
    }

    /// A 1px hairline of light along the top edge of a surface, fading out
    /// before it reaches the bottom.
    ///
    /// This one detail is what separates an authored card from a rounded
    /// rectangle: the surface stops being a flat fill and becomes a plane
    /// tilted into the same light the hero is lit by. `Theme.surfaceEdge` is
    /// white at 7% — about one rung of the ink ladder over `Theme.surface`,
    /// which is exactly a hairline's worth.
    ///
    /// The path is closed because `strokeBorder` needs a shape, but the ramp is
    /// clear by 60% of the way down, so only the top edge and the shoulders of
    /// the corners ever carry any light. A visible closed outline would read as
    /// system chrome, which is the thing being avoided.
    ///
    /// Decorative and inert: hidden from VoiceOver and transparent to hit
    /// testing, because most of these surfaces are inside buttons.
    func ocrTopEdgeHighlight(_ shape: some InsettableShape) -> some View {
        overlay {
            shape
                .strokeBorder(
                    LinearGradient(
                        stops: [
                            .init(color: Theme.surfaceEdge, location: 0),
                            .init(color: Theme.surfaceEdge.opacity(0), location: 0.6)
                        ],
                        startPoint: .top,
                        endPoint: .bottom
                    ),
                    lineWidth: 1
                )
                .allowsHitTesting(false)
                .accessibilityHidden(true)
        }
    }
}
