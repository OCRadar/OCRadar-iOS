import SwiftUI

/// Opaque card. Replaces the old translucent `GlassCard` treatment — the
/// restyle is deliberately not glassy.
///
/// The fill is `Theme.surface`; the top edge carries a hairline of light
/// (`View.ocrTopEdgeHighlight(_:)`). That hairline is the whole difference
/// between an authored card and a rounded rectangle — it makes the card read
/// as a plane tilted into the same light the hero panel is lit by, rather than
/// as an untreated flat fill. It is light caught on an edge, not a border: the
/// ramp is clear well before the bottom, so there is never a closed outline.
///
/// `padding: 0` is the escape hatch for row groups whose dividers have to run
/// edge to edge; those rows own their own horizontal inset. The highlight is an
/// overlay on the card's own shape, so it survives that case unchanged.
struct OCRCard<Content: View>: View {
    var corner: CGFloat = Theme.cardCorner
    var padding: CGFloat = 18
    @ViewBuilder var content: Content

    var body: some View {
        content
            .padding(padding)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(Theme.surface, in: .rect(cornerRadius: corner))
            .ocrTopEdgeHighlight(RoundedRectangle(cornerRadius: corner))
    }
}

/// The 13/600 label that sits above a card group.
struct OCRSectionLabel: View {
    private let text: String

    init(_ text: String) {
        self.text = text
    }

    var body: some View {
        Text(text)
            .font(.ocrSectionLabel())
            .foregroundStyle(Theme.textSecondary)
            .frame(maxWidth: .infinity, alignment: .leading)
    }
}

/// The pair of concentric outlines that bleed off the top-right of every
/// gradient panel, echoing the radar rings in the app mark.
///
/// Home's hero draws two, and it is the screen the direction singled out; the
/// bands and sheets used to draw only one, which is why they read as a reduced
/// version of the hero instead of the same idea at another size. Two rings is
/// the difference between "a circle" and "a radar".
///
/// The pair is genuinely **concentric** — the inner ring's offset is derived
/// from the outer's rather than eyeballed, because two circles that nearly
/// share a centre read as a mistake where two that exactly share one read as a
/// motif. `scale` is the hero's own ratio (130/230 ≈ 0.565).
///
/// Both rings sit at `white 14%`, the value the hero and every existing band
/// already use. Purely decorative; the caller hides the whole background layer
/// from VoiceOver.
struct OCRPanelRings: View {
    var outerDiameter: CGFloat
    /// Offset of the outer ring from the panel's top-*trailing* corner. The
    /// ring is expected to bleed: positive `width` pushes it off the right
    /// edge, negative `height` above the top, and the panel's clip trims it.
    var outerOffset: CGSize
    var scale: CGFloat = 0.565
    var opacity: Double = 0.14

    private var innerDiameter: CGFloat { (outerDiameter * scale).rounded() }

    /// In a `.topTrailing` stack a circle of diameter `d` at offset `x` has its
    /// centre at `x - d / 2` from the trailing edge, and at `y + d / 2` from
    /// the top. Solving both for the outer ring's centre gives the inner one.
    private var innerOffset: CGSize {
        CGSize(
            width: outerOffset.width - (outerDiameter - innerDiameter) / 2,
            height: outerOffset.height + (outerDiameter - innerDiameter) / 2
        )
    }

    var body: some View {
        ZStack(alignment: .topTrailing) {
            // Fills the panel so both rings anchor to its top-right corner
            // rather than to each other's frames.
            Color.clear
            ring(diameter: outerDiameter, offset: outerOffset)
            ring(diameter: innerDiameter, offset: innerOffset)
        }
        // Decorative and inert. `Color.clear` is hit-testable in SwiftUI, so
        // without this the panel-filling spacer above would be a live surface
        // sitting across every gradient header — the same rule
        // `ocrTopEdgeHighlight`, `ocrPanelSpill` and `OCRAmbientBackground`
        // already keep.
        .allowsHitTesting(false)
        .accessibilityHidden(true)
    }

    private func ring(diameter: CGFloat, offset: CGSize) -> some View {
        Circle()
            .strokeBorder(.white.opacity(opacity), lineWidth: 1)
            .frame(width: diameter, height: diameter)
            .offset(x: offset.width, y: offset.height)
    }
}

/// The compact gradient band used by Scan, History and Settings: bottom
/// corners 30, title and subtitle bottom-left, an optional trailing caption
/// bottom-right.
///
/// Two shapes, both measured from the design:
///
/// - **Scan** pins the band to a `fixedHeight` of 150 with its content 22 from
///   the bottom, because the camera stage below it is positioned absolutely
///   (top 166) and would drift if the band grew.
/// - **History and Settings** are content-driven — 96 above the title, 24
///   below the subtitle — which comes out taller than 150. Forcing those to
///   150 crushed the 96pt top inset the design uses to clear the status bar.
///
/// Home and the sheets use the same treatment with a taller body — see
/// `Theme.hero` and `OCRSheetHeader`.
struct OCRHeaderBand<Trailing: View>: View {
    let title: String
    let subtitle: String
    /// 150 for Scan; `nil` lets the 96/24 padding size the band.
    var fixedHeight: CGFloat? = nil
    @ViewBuilder var trailing: Trailing

    var body: some View {
        content
            .background {
                ZStack(alignment: .topTrailing) {
                    Theme.band
                    OCRPanelRings(outerDiameter: 190, outerOffset: CGSize(width: 56, height: -52))
                }
                .accessibilityHidden(true)
            }
            .clipShape(.rect(bottomLeadingRadius: Theme.bandCorner,
                             bottomTrailingRadius: Theme.bandCorner))
            // The band's bottom edge used to be a hard chromatic cut: the
            // gradient's light end straight onto the ink. It now spills a
            // little of its own light down onto the canvas, which is what makes
            // it read as lit rather than pasted on.
            .ocrPanelSpill()
            .foregroundStyle(.white)
    }

    @ViewBuilder
    private var content: some View {
        if let fixedHeight {
            // `minHeight`, not `height`: the title and subtitle both scale, and
            // at accessibility sizes the bottom-aligned pair outgrew 150 and was
            // clipped upward by the band's own `clipShape` (sliding under the
            // status bar on the way). `fixedSize` keeps the band at exactly that
            // ideal height instead of letting the flexible frame split the
            // screen with the Scan stage below it; the stage is the flexible
            // one, so a taller band costs stage height, never legibility.
            titleRow
                .padding(.horizontal, Theme.pageMargin)
                .padding(.bottom, 22)
                .frame(
                    maxWidth: .infinity,
                    minHeight: fixedHeight,
                    alignment: .bottomLeading
                )
                .fixedSize(horizontal: false, vertical: true)
        } else {
            titleRow
                .padding(.horizontal, Theme.pageMargin)
                .padding(.top, 96)
                .padding(.bottom, 24)
        }
    }

    private var titleRow: some View {
        HStack(alignment: .bottom) {
            VStack(alignment: .leading, spacing: 6) {
                Text(title)
                    .font(.ocrScreenTitle())
                    .tracking(-0.7)
                Text(subtitle)
                    .font(.ocrMeta())
                    .foregroundStyle(Theme.onGradient())
            }
            .fixedSize(horizontal: false, vertical: true)
            Spacer(minLength: Theme.spacingM)
            trailing
                .font(.system(size: 13))
                .foregroundStyle(Theme.onGradient())
        }
    }
}

/// The gradient header shared by the Result and Scan-detail sheets: an eyebrow
/// and a Done button, then the record's meta line, confidence numeral, class
/// name and risk tier.
///
/// Every value is passed in by the presenting screen so the header can only
/// ever show the record it was given (honesty rule 6).
///
/// The header panel itself stays a flat gradient — it is content, and its
/// white-on-gradient labels are measured against those exact stops. Only the
/// Done capsule floating on top of it is glass.
struct OCRSheetHeader: View {
    @Environment(\.accessibilityReduceTransparency) private var reduceTransparency

    let eyebrow: String
    let meta: String
    let percentText: String
    let title: String
    let tierText: String
    let onDone: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            HStack {
                Text(eyebrow)
                    .font(.system(size: 15, weight: .semibold))
                    .tracking(-0.1)
                Spacer(minLength: Theme.spacingM)
                Button(action: onDone) {
                    Text("Done")
                        .font(.system(size: 15, weight: .semibold))
                        .padding(.horizontal, Theme.spacingM)
                        .frame(minWidth: Theme.minTarget, minHeight: 34)
                        // Untinted, for the reason spelled out on Home's hero
                        // gear button: over the header's `#724398` a `white 20%`
                        // tint lifted the capsule to `#AF7BC8` and dropped the
                        // white label to **3.24:1**, below the 4.5 floor and
                        // below the 4.40:1 the flat fill measured. Untinted it
                        // sits at `#9457B6` for **4.89:1** — better than the
                        // treatment it replaces — and the specular rim is what
                        // makes it read as a button.
                        //
                        // The Reduce Transparency fallback is *not* that flat
                        // `white 20%`. This is the only way out of the sheet
                        // other than a swipe, its 15/600 label is body text,
                        // and the wash measures 4.40:1 on the header's mid
                        // tones and 4.15:1 on the `#7C479B` the capsule
                        // actually sits on — under the floor, and unlike the
                        // Scan surfaces this backdrop is `Theme.hero` every
                        // time, so it fails deterministically rather than only
                        // over a bright photo. `gradientControlFill` is the
                        // gradient's own deepest stop, opaque, and holds the
                        // white label at 10.1:1 wherever the capsule lands.
                        .ocrGlass(
                            .capsule,
                            interactive: true,
                            fallback: Theme.gradientControlFill,
                            reduceTransparency: reduceTransparency
                        )
                        // 34pt capsule, 44pt touch target — this is the only
                        // way out of the sheet other than a swipe. The outer
                        // negative padding keeps the capsule on the measured
                        // 22pt top inset, matching the gear button on Home.
                        .frame(minHeight: Theme.minTarget)
                        .contentShape(.rect)
                }
                .buttonStyle(.plain)
                .foregroundStyle(.white)
                .padding(.vertical, -(Theme.minTarget - 34) / 2)
            }
            .padding(.bottom, 30)

            Text(meta)
                .font(.system(size: 13.5, weight: .medium))
                .foregroundStyle(Theme.onGradient())
                .padding(.bottom, 12)

            // The 76pt numeral scales with Dynamic Type; it shrinks rather
            // than clipping when the text size runs away with it.
            Text(percentText)
                .font(.ocrHeroNumeral())
                .tracking(-3.6)
                .monospacedDigit()
                .lineLimit(1)
                .minimumScaleFactor(0.4)
                .ocrHeroLineHeight()
                .padding(.bottom, Theme.spacingS)

            Text(title)
                .font(.ocrScreenTitle())
                .tracking(-0.7)
                .fixedSize(horizontal: false, vertical: true)
                .padding(.bottom, 6)

            Text(tierText)
                .font(.system(size: 15.5))
                .foregroundStyle(Theme.onGradient())
                .fixedSize(horizontal: false, vertical: true)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.horizontal, Theme.pageMargin)
        .padding(.top, 22)
        .padding(.bottom, 30)
        .background {
            ZStack(alignment: .topTrailing) {
                Theme.hero
                OCRPanelRings(outerDiameter: 220, outerOffset: CGSize(width: 70, height: -56))
            }
            .accessibilityHidden(true)
        }
        .clipShape(.rect(bottomLeadingRadius: Theme.heroCorner,
                         bottomTrailingRadius: Theme.heroCorner))
        // Same lit bottom edge as the header bands — the sheet's own canvas
        // picks up a little of the header's light instead of butting against
        // the gradient's lightest stop.
        .ocrPanelSpill()
        .foregroundStyle(.white)
    }
}

/// Outlined notice marking a demo result. The salmon dot is data-only styling —
/// the copy itself is white and passes contrast on its own.
///
/// `title` and `message` are always supplied in full by the caller; the two
/// sheets word this differently and neither wording may be shortened.
struct OCRDemoNotice: View {
    /// `Theme.noticeBorder` with `Theme.surfaceEdge` composited over it:
    /// `#302B3B` + white 7% = `#3E3A49`, L\* 25.4 against the border's 18.7.
    /// One rung of the ink ladder, the same step the cards' top edge takes.
    ///
    /// The notice is the one card in the app with no fill, so it cannot use
    /// `ocrTopEdgeHighlight` — a translucent white hairline drawn over the
    /// canvas lands *below* the border it is meant to be lighting. It gets the
    /// same idea as an opaque ramp on the outline itself instead.
    private static let litBorder = Color(hex: 0x3E3A49)

    let title: String
    let message: String

    var body: some View {
        HStack(alignment: .top, spacing: 11) {
            Circle()
                .fill(Theme.salmon)
                .frame(width: 8, height: 8)
                .padding(.top, 6)
                .accessibilityHidden(true)
            copy
        }
        // The design's body line-height, named as the ratio it is rather than
        // as the 4pt literal that happens to produce it at 13.5.
        .ocrBodyLeading(size: 13.5)
        .fixedSize(horizontal: false, vertical: true)
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.vertical, Theme.spacingM)
        .padding(.horizontal, 18)
        .overlay {
            // Lit at the top, settling to `noticeBorder` by a third of the way
            // down: the outline is the notice's only surface treatment, so it
            // is where the card's light has to happen.
            RoundedRectangle(cornerRadius: Theme.rowCorner)
                .strokeBorder(
                    LinearGradient(
                        stops: [
                            .init(color: Self.litBorder, location: 0),
                            .init(color: Theme.noticeBorder, location: 0.35)
                        ],
                        startPoint: .top,
                        endPoint: .bottom
                    ),
                    lineWidth: 1
                )
                // Decorative and inert, matching every other decorative layer
                // in the pass: it is an overlay, so it must not intercept a tap
                // meant for whatever the notice is stacked with.
                .allowsHitTesting(false)
                .accessibilityHidden(true)
        }
        .accessibilityElement(children: .combine)
    }

    /// The title runs bold-white into the message as one flowing paragraph,
    /// exactly as the design draws it — so it is one `Text`, not two.
    private var copy: Text {
        var notice = AttributedString(title)
        notice.font = .system(size: 13.5, weight: .semibold)
        notice.foregroundColor = Theme.textPrimary
        var rest = AttributedString(" " + message)
        rest.font = .system(size: 13.5)
        rest.foregroundColor = Theme.textSecondary
        notice.append(rest)
        return Text(notice)
    }
}
