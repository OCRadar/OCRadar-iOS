import SwiftUI

/// The three pieces of chrome every row in the app is built from: the leading
/// accent glyph, the trailing disclosure chevron, and the meta line under the
/// title.
///
/// They live together because their defect was the same defect. Each screen
/// re-specified them from literals, so the *same* affordance was drawn three
/// ways: the disclosure chevron at 20/regular on Home, 15/semibold on History
/// and 14/semibold on Settings — on rows that otherwise agree to a third of a
/// point — and the leading icon at 19 in Settings against 21 in the Result
/// callout. Nothing here is a new effect. It is the same vocabulary, specified
/// once, so that a tab switch stops rewriting it.

// MARK: - Leading icon

/// The one treatment for a leading row glyph: an accent SF Symbol in a fixed
/// optical box, anchored to the cap band of the title it labels.
///
/// **One size, one weight, one box.** Symbols do not share a bounding box —
/// `envelope` is wide and short, `doc.text` and `lock.shield` are tall and
/// narrow — so matching point sizes is not enough to make a column of them look
/// even. The fixed `box` is what puts every glyph's *centre* on one rail; the
/// shared `weight` is what stops one row's stroke reading heavier than the next.
///
/// `.medium` rather than the regular weight the screens used: the row title
/// beside it is 16/500, and a regular-weight glyph next to a medium title reads
/// as a lighter, unrelated object. 18pt at `.medium` carries the same stroke as
/// the title at slightly smaller optical size, which is the relationship a
/// leading glyph should have — it introduces the title, it does not compete
/// with it.
///
/// **`box` is deliberately not scaled.** `SettingsMetrics` derives its divider
/// inset from this width (18 + 21 + 14 = 53), and a divider that starts where
/// the row's text starts is only true if the rail is a constant. The glyph
/// inside it is free to be whatever the symbol is; the rail is not.
///
/// Decorative: every call site states the same thing in the row's title, so the
/// glyph is hidden from VoiceOver.
struct OCRRowIcon: View {
    /// The optical rail. `SettingsMetrics.iconWidth` is this number.
    static let box: CGFloat = 21
    /// Gap between the glyph box and the title it introduces — the second half
    /// of the icon rail, and the number every call site must share for a
    /// divider to start where the row's text starts. Settings used 14 and the
    /// Result callout and the Privacy card used 12.
    static let gap: CGFloat = 14
    /// The one point size for a leading row glyph.
    static let glyphSize: CGFloat = 18

    let systemName: String
    /// Accent everywhere today; a parameter so a status row can tint one
    /// without inventing a second icon treatment.
    var tint: Color = Theme.accent
    /// Point size of the title this glyph introduces, for cap-band centring.
    var titleSize: CGFloat = 16

    var body: some View {
        Image(systemName: systemName)
            .font(.system(size: Self.glyphSize, weight: .medium))
            // Every symbol in the app is a monochrome outline; naming it means
            // a future symbol with a colour palette cannot quietly render at a
            // different optical weight from the ones beside it.
            .symbolRenderingMode(.monochrome)
            .foregroundStyle(tint)
            .frame(width: Self.box, height: Self.box)
            .ocrCapCentred(on: titleSize)
            .accessibilityHidden(true)
    }
}

// MARK: - Disclosure chevron

/// The one disclosure chevron. Every row that opens something uses this and
/// nothing else.
///
/// **Size 13, semibold.** The glyph's ink is ~0.87 × its point size, so 13pt
/// draws an 11.3pt chevron against the 16pt row title's 11.2pt cap height:
/// the chevron is exactly as tall as the capitals it sits beside. That is the
/// relationship that makes it read as secondary. The 15pt the rows used
/// measured 13pt tall — taller than the title's caps — and the 20pt on Home
/// measured 16.7, which is why the Home rail and a History row could not be
/// looked at together.
///
/// **`Theme.chevron`, not a lighter grey.** It is a non-text control, so its
/// floor is 3:1, and it is drawn on `Theme.surface` rather than on the canvas.
///
/// **The fixed `railWidth` is the trailing anchor.** The chevron is the last
/// element in its row, so the box's trailing edge *is* the row's content edge;
/// pinning the width puts the ink a constant distance inside it on every screen
/// instead of letting each glyph's side bearing decide. Vertically it anchors
/// to the title's cap band via `ocrCapCentred(on:)` — put it in an
/// `HStack(alignment: .firstTextBaseline)` and it stops floating in the middle
/// of the row box.
///
/// **The point size scales, and it has to.** An earlier note here claimed
/// `Font.system(size:)` was scaled by Dynamic Type on its own and made the size
/// a plain constant on that basis. It is not — a system font declared by point
/// size is fixed (see `OCRTextStyle`) — so the constant meant the chevron alone
/// stayed 13pt while the title it is specified to match reached 50pt at AX5.
/// Both the glyph and its `rail` are therefore `@ScaledMetric` on `.body`, the
/// curve the 16pt row title now grows along, so the two keep their measured
/// relationship at every text size instead of only the default one.
///
/// Decorative: the row itself carries the button trait and the label.
struct OCRChevron: View {
    /// The trailing column the glyph is centred in.
    static let railWidth: CGFloat = 10
    /// The one point size for a disclosure chevron.
    static let glyphSize: CGFloat = 13

    /// Point size of the title this chevron discloses, for cap-band centring.
    var titleSize: CGFloat = 16

    @ScaledMetric(relativeTo: .body) private var rail: CGFloat = OCRChevron.railWidth
    @ScaledMetric(relativeTo: .body) private var glyph: CGFloat = OCRChevron.glyphSize

    var body: some View {
        Image(systemName: "chevron.right")
            .font(.system(size: glyph, weight: .semibold))
            .symbolRenderingMode(.monochrome)
            .foregroundStyle(Theme.chevron)
            .frame(width: rail)
            .ocrCapCentred(on: titleSize)
            .accessibilityHidden(true)
    }
}

// MARK: - Meta line

/// The line under a row title: `"Worth asking about · Demo · 1h"`.
///
/// Same information, same short date tokens, same order — `design/README.md`
/// pins all three. What changes is that the three tokens stop carrying equal
/// weight. As one flat string at 13.5/400 they read as a run of clutter, and
/// the eye has no reason to land on any of them first:
///
/// - **Tier** is the fact the row is about, so it takes the weight: 13.5/**500**
///   in `textSecondary`. The type table gives row meta as `500/400`, so both
///   ends of this hierarchy are values the design already sanctions.
/// - **Demo** stops being another grey word in the dot run and becomes a
///   *marker*: the separator in front of it is replaced by a filled salmon dot,
///   twice the diameter of the neutral ones. That is the same salmon dot the
///   demo notice and the model-status card already use, so the honesty surface
///   is now stated in the app's own established sign for it rather than in
///   another word. The word itself stays at full `textSecondary` — it is an
///   honesty surface and it must stay plainly legible, so the marker is what is
///   quiet, not the label.
/// - **Timestamp** is the least load-bearing token, so it is lightest:
///   `textTertiary` at 400 (4.76:1 on `Theme.surface`, which is the only fill
///   this line is ever drawn on). It is the one token that may truncate, which
///   is also how the single-string version behaved.
///
/// The separators are `Circle`s rather than the `·` glyph so their size, colour
/// and optical position are specified rather than inherited from the font's
/// idea of a middle dot — and so the demo marker can be the *same element* one
/// size up in one colour, which is what keeps it from reading as decoration.
struct OCRMetaLine: View {
    /// e.g. "Worth asking about". Always `RiskLevel.displayLabel`, which is
    /// next-step guidance and never a severity, and never abbreviated.
    let tier: String
    /// The short date token the design pins: `1h` / `1d` / `5d`.
    let timestamp: String
    /// Marks a record produced by the demo stand-in classifier. Callers pass
    /// the record's own flag; this view never infers it.
    var isDemo: Bool = false

    @ScaledMetric(relativeTo: .footnote) private var separatorDot: CGFloat = 2.5
    @ScaledMetric(relativeTo: .footnote) private var markerDot: CGFloat = 5

    /// Gap on each side of a neutral separator.
    private let separatorGap: CGFloat = 5
    /// The demo marker gets a touch more air than a separator, which is half of
    /// what makes it read as a marker and not as punctuation.
    private let markerGap: CGFloat = 7

    /// A dot run reads across a line, and takes the line it needs — which is
    /// why this is a `ViewThatFits` and not a text-size threshold. Whether
    /// "Moderate risk · Demo · yesterday" fits on one line is a question about
    /// this row's width and this reader's type size together, and `ViewThatFits`
    /// is the one thing that can ask it that way: it keeps the design's run
    /// wherever the run fits and drops to a stack exactly where it stops
    /// fitting, on a long class name at a reading size just as much as at AX3.
    ///
    /// It also fixes the failure this line used to cause. A view reports the
    /// width its contents demand, and this one demanded whatever the run came
    /// to — so at accessibility sizes the row asked for more width than the
    /// display had, the root `ZStack` grew to its widest child, and ~40pt was
    /// clipped off both edges of the whole app. A `ViewThatFits` cannot ask for
    /// more than it is offered.
    var body: some View {
        ViewThatFits(in: .horizontal) {
            run
            stacked
        }
    }

    /// The design's line: `"Worth asking about · Demo · 1h"`.
    private var run: some View {
        HStack(alignment: .firstTextBaseline, spacing: 0) {
            tierText
            if isDemo {
                demoMarker
                    .padding(.leading, markerGap)
                    .padding(.trailing, markerGap - 1)
                demoText
            }
            dot(diameter: separatorDot, fill: Theme.textTertiary)
                .padding(.horizontal, separatorGap)
            timestampText
        }
        // One line or nothing: a run that has started wrapping is no longer the
        // design's run, and is exactly the case `stacked` is for.
        .lineLimit(1)
        .accessibilityElement(children: .combine)
    }

    /// The same three tokens, one per line, for when they cannot share one.
    ///
    /// Nothing here is pinned to its intrinsic width. The two
    /// `fixedSize(horizontal: true, …)` calls this line used to carry — on the
    /// tier and on "Demo", to give them truncation precedence over the
    /// timestamp — meant the row could not compress *at all*. Precedence
    /// between tokens is only meaningful while they share a line, and here they
    /// do not.
    private var stacked: some View {
        VStack(alignment: .leading, spacing: 2) {
            tierText
            if isDemo {
                HStack(alignment: .firstTextBaseline, spacing: markerGap) {
                    demoMarker
                    demoText
                }
            }
            timestampText
        }
        .accessibilityElement(children: .combine)
    }

    private var tierText: some View {
        Text(tier)
            .ocrFont(.meta.weight(.medium))
            .foregroundStyle(Theme.textSecondary)
    }

    /// The salmon marker that replaces a separator in front of "Demo" — the
    /// app's established sign for a stand-in result, so it stays in both
    /// arrangements.
    private var demoMarker: some View {
        dot(diameter: markerDot, fill: Theme.salmon)
    }

    private var demoText: some View {
        Text("Demo")
            .ocrFont(.meta)
            .foregroundStyle(Theme.textSecondary)
    }

    private var timestampText: some View {
        Text(timestamp)
            .ocrFont(.meta)
            // A value the user compares down a column of rows.
            .monospacedDigit()
            .foregroundStyle(Theme.textTertiary)
            .lineLimit(1)
    }

    private func dot(diameter: CGFloat, fill: Color) -> some View {
        Circle()
            .fill(fill)
            .frame(width: diameter, height: diameter)
            // Sits on the meta line's own x-height band rather than on the row's
            // centre, so it reads as punctuation between two words instead of
            // as an object parked beside them.
            .ocrXHeightCentred(on: 13.5)
            .accessibilityHidden(true)
    }
}

#Preview("Row chrome") {
    VStack(spacing: Theme.spacingS) {
        ForEach([true, false], id: \.self) { isDemo in
            HStack(alignment: .firstTextBaseline, spacing: Theme.spacingM) {
                OCRRowIcon(systemName: "doc.text")
                VStack(alignment: .leading, spacing: 3) {
                    Text("Common tissue appearance")
                        .ocrFont(.rowTitle)
                        .tracking(-0.2)
                        .foregroundStyle(Theme.textPrimary)
                    OCRMetaLine(tier: "Worth asking about", timestamp: "1h", isDemo: isDemo)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                OCRChevron()
            }
            .padding(.vertical, Theme.spacingM)
            .padding(.horizontal, 18)
            .background(Theme.surface, in: .rect(cornerRadius: Theme.rowCorner))
            .ocrTopEdgeHighlight(RoundedRectangle(cornerRadius: Theme.rowCorner))
        }
    }
    .padding(Theme.pageMargin)
    .frame(maxWidth: .infinity, maxHeight: .infinity)
    .background { OCRAmbientBackground() }
    .preferredColorScheme(.dark)
}
