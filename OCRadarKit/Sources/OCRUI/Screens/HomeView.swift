import OCRCore
import SwiftData
import SwiftUI

/// Landing tab: a full-bleed gradient hero carrying the most recent scan, the
/// two scans before it, a confidence trend, the model-status card and the
/// short medical disclaimer.
///
/// Data-driven: everything below the wordmark comes from SwiftData. With no
/// saved scans the hero degrades to an invitation and the earlier-scans and
/// chart sections are omitted entirely; with a single scan the chart is still
/// omitted, because a one-point line says nothing.
struct HomeView: View {
    @Environment(\.lesionClassifier) private var classifier
    @Environment(\.ocrLogo) private var logo
    @Environment(\.selectTab) private var selectTab

    @Query(sort: \ScanRecord.timestamp, order: .reverse) private var records: [ScanRecord]

    @State private var detailRecord: ScanRecord?
    @State private var isShowingDisclaimer = false

    /// Width of the earlier-scans numeral column. Scaled so a two-digit value
    /// still fits its column at accessibility text sizes — but *bounded*: at
    /// AX5 the `.body` metric takes 52 to about 160, and an unbounded column
    /// left the title less room than the number beside it, which is what pushed
    /// the row past the width of the display. Past the cap the numeral shrinks
    /// inside its column instead (`minimumScaleFactor` below), and above
    /// `isAccessibilitySize` the column stops sharing a line with the title
    /// altogether — see `earlierScansRows`.
    @ScaledMetric(relativeTo: .body) private var railNumeralWidth: CGFloat = 52

    /// The most the numeral column may take from the title beside it: 1.5× the
    /// design's 52, reached at about AX1.
    private static let railNumeralMaxWidth: CGFloat = 78

    /// `modelStatusText` builds an `AttributedString`, whose runs carry a
    /// `Font` — and a `Font` cannot read the environment. So that one run
    /// scales its own point size, on `OCRTextStyle.meta`'s curve.
    @ScaledMetric(relativeTo: .subheadline)
    private var metaFontSize: CGFloat = OCRTextStyle.meta.size

    /// Above this, a row lays its numeral out *above* its title rather than
    /// beside it. A row is three columns of chrome around one line of text, and
    /// at accessibility sizes the text needs the whole width.
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize

    /// SF Pro's left side bearing on the hero numeral: 0.047em, which at the
    /// design's 76pt is 3.6 invisible points. It is a property of the glyphs
    /// actually drawn, so now that the numeral grows with Dynamic Type the
    /// compensation has to grow with it — on `OCRTextStyle.heroNumeral`'s own
    /// `.largeTitle` curve, or the largest object on the screen would walk off
    /// the page rail as the text size rose.
    @ScaledMetric(relativeTo: .largeTitle)
    private var heroNumeralBearing: CGFloat = OCRTextStyle.heroNumeral.size * 0.047

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 0) {
                hero
                pageBody
            }
        }
        .scrollIndicators(.hidden)
        .ocrQAScrollBottom()
        .background { OCRAmbientBackground() }
        // The hero is full-bleed to the top edge; its 96pt top padding is what
        // clears the status bar, so the top edge effect stays off while the page
        // is at rest and comes back the moment anything scrolls under there. The
        // bottom one is on and soft, so the page dissolves under the tab bar.
        .ocrScrollEdges()
        .sheet(item: $detailRecord) { record in
            HistoryDetailView(record: record)
                .presentationCornerRadius(Theme.sheetCorner)
                .presentationBackground(Theme.canvas)
        }
        .sheet(isPresented: $isShowingDisclaimer) {
            // A re-read, not the acknowledgement gate — so "Done", never
            // "I understand".
            MedicalDisclaimerSheet(
                title: "Medical disclaimer",
                actionTitle: "Done",
                onAction: { isShowingDisclaimer = false }
            )
            .medicalDisclaimerPresentation()
        }
    }

    // MARK: - Hero

    private var hero: some View {
        VStack(alignment: .leading, spacing: 0) {
            wordmarkRow
                .padding(.bottom, 36)

            if let latest = records.first {
                latestBlock(latest)
            } else {
                emptyHeroBlock
            }

            Button {
                selectTab(.scan)
            } label: {
                HStack(spacing: 9) {
                    // No size of its own: the glyph inherits the button style's
                    // 16.5/600, exactly as the `Label` in History's empty state
                    // does. Pinned at 20/regular it was a third heavier and a
                    // stroke lighter than the words beside it — the same
                    // mismatch on the app's two most prominent calls to action.
                    Image(systemName: "camera.fill")
                        .symbolRenderingMode(.monochrome)
                        .accessibilityHidden(true)
                    Text("New scan")
                }
            }
            .buttonStyle(OCRInverseButtonStyle())
            .padding(.top, 30)
        }
        .padding(.top, 96)
        .padding(.horizontal, Theme.pageMargin)
        .padding(.bottom, 30)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background {
            ZStack(alignment: .topTrailing) {
                Theme.hero
                decorativeRings
            }
        }
        .clipShape(
            .rect(
                bottomLeadingRadius: Theme.heroCorner,
                bottomTrailingRadius: Theme.heroCorner
            )
        )
        // The hero is where this idiom comes from, so it cannot be the one
        // panel without it: the header bands and both sheet headers now spill a
        // little of their own light onto the ink below their bottom edge, and a
        // hero that still ended on a hard chromatic cut would have read as the
        // odd one out on the screen the direction singled out.
        .ocrPanelSpill()
        .foregroundStyle(.white)
    }

    /// The concentric outlines bleeding off the top-right corner — they echo
    /// the radar rings in the app mark.
    ///
    /// The hero's own numbers (230 at 70/−40, and an inner ring at exactly
    /// 0.565 of that, concentric with it) are what `OCRPanelRings` was derived
    /// from, so this now *calls* the shared motif rather than being a second
    /// copy of it. The bands and the sheet headers draw the same pair at their
    /// own sizes; the hero is no longer the only screen with two rings.
    private var decorativeRings: some View {
        OCRPanelRings(
            outerDiameter: 230,
            outerOffset: CGSize(width: 70, height: -40)
        )
    }

    private var wordmarkRow: some View {
        HStack(spacing: 9) {
            logoMark
            Text("OCRadar")
                .ocrFont(.cardTitle)
                .tracking(-0.2)
            Spacer(minLength: Theme.spacingM)
            Button {
                selectTab(.settings)
            } label: {
                // `.medium`, monochrome — the weight every SF Symbol in the app
                // is now drawn at, from the tab bar's four glyphs to the accent
                // icons on the Settings rail. A regular-weight gear beside a
                // 16.5/600 wordmark read as a lighter, borrowed object.
                Image(systemName: "gearshape.fill")
                    .font(.system(size: 19, weight: .medium))
                    .symbolRenderingMode(.monochrome)
                    .foregroundStyle(.white)
                    .frame(width: 34, height: 34)
                    .modifier(HeroGlassCircle())
                    // 34pt visual, 44pt touch target; the negative padding
                    // keeps the circle on the 26pt page margin.
                    .frame(width: Theme.minTarget, height: Theme.minTarget)
                    .contentShape(.circle)
            }
            .buttonStyle(.plain)
            .padding(.trailing, -(Theme.minTarget - 34) / 2)
            .accessibilityLabel("Settings")
        }
    }

    @ViewBuilder
    private var logoMark: some View {
        if let logo {
            logo
                .resizable()
                .scaledToFill()
                .frame(width: 26, height: 26)
                .clipShape(.circle)
                .accessibilityHidden(true)
        } else {
            // The app mark lives in the app target; previews and tests run
            // without it, so stand in with a plain ring rather than nothing.
            ZStack {
                Circle().strokeBorder(.white.opacity(0.6), lineWidth: 1.2)
                Circle().fill(.white.opacity(0.9)).frame(width: 9, height: 9)
            }
            .frame(width: 26, height: 26)
            .accessibilityHidden(true)
        }
    }

    private func latestBlock(_ record: ScanRecord) -> some View {
        Button {
            detailRecord = record
        } label: {
            VStack(alignment: .leading, spacing: 0) {
                Text("Last scan · \(HomeFormat.relative(record.timestamp))")
                    .ocrFont(.meta.weight(.medium))
                    .foregroundStyle(Theme.onGradient())
                    .padding(.bottom, 12)
                // Same guard the sheet header carries: the 76pt numeral scales
                // with Dynamic Type and the hero clips its own bounds, so it
                // has to shrink rather than run under the panel edge.
                Text(ConfidencePercent.text(record.probability))
                    .ocrFont(.heroNumeral)
                    .tracking(-3.6)
                    .monospacedDigit()
                    .lineLimit(1)
                    .minimumScaleFactor(0.4)
                    .ocrHeroLineHeight()
                    .padding(.bottom, 10)
                    // The numeral's *frame* was always on the 26pt page rail;
                    // its ink was not. SF Pro carries a left side bearing of
                    // about 0.047em, which at 76pt is 3.6 invisible points — so
                    // the largest object on the screen was the only one of the
                    // five stacked elements off the rail, while the capsule,
                    // the meta line, the class name and the tier all sat on it.
                    // Nothing else compensates for it, so this does.
                    // Read out of the view before the closure: `alignmentGuide`
                    // hands its builder out without isolation, and `OCRUI`
                    // compiles with `defaultIsolation(MainActor)`.
                    .alignmentGuide(.leading) { [bearing = heroNumeralBearing] in
                        $0[.leading] + bearing
                    }
                Text(record.topClassName)
                    .ocrFont(.screenTitle)
                    .tracking(-0.7)
                    .fixedSize(horizontal: false, vertical: true)
                    .padding(.bottom, 6)
                Text(tierLine(for: record))
                    .ocrFont(.listValue)
                    .foregroundStyle(Theme.onGradient())
            }
            .multilineTextAlignment(.leading)
            .frame(maxWidth: .infinity, alignment: .leading)
            .contentShape(.rect)
        }
        .buttonStyle(.plain)
        .accessibilityLabel(latestAccessibilityLabel(for: record))
        .accessibilityHint("Opens this scan's details.")
    }

    private var emptyHeroBlock: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("No scans yet")
                .ocrFont(.screenTitle)
                .tracking(-0.7)
            Text("Take your first scan to see your results here.")
                .ocrFont(.listValue)
                .foregroundStyle(Theme.onGradient())
                .fixedSize(horizontal: false, vertical: true)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    /// "Low risk" — plus the demo suffix, and only ever for a demo record.
    private func tierLine(for record: ScanRecord) -> String {
        record.isDemoResult
            ? "\(record.riskLevel.displayLabel) · demo result"
            : record.riskLevel.displayLabel
    }

    private func latestAccessibilityLabel(for record: ScanRecord) -> String {
        var label = "Most recent scan: \(record.topClassName.lowercased()), "
        label += "\(ConfidencePercent.value(record.probability)) percent confidence, "
        label += "\(record.riskLevel.displayLabel.lowercased()), "
        label += HomeFormat.relative(record.timestamp)
        if record.isDemoResult {
            label += ", demo result"
        }
        return label
    }

    // MARK: - Body

    /// One gap between siblings, `spacingL`, all the way down. The page used to
    /// run 34 / 22 / 16, shrinking monotonically for no reason a reader could
    /// name, so the one screen with three stacked cards was the one with no
    /// rhythm. The section head keeps a tighter `spacingM` because it belongs
    /// to the rows beneath it rather than standing between two siblings.
    private var pageBody: some View {
        VStack(alignment: .leading, spacing: 0) {
            // The newest record is the hero, so the list and the trend only
            // have something to say from the second record onwards.
            if records.count >= 2 {
                earlierScansHeader
                    .padding(.bottom, Theme.spacingM)
                earlierScansRows
                    .padding(.bottom, Theme.spacingL)
                chartCard
                    .padding(.bottom, Theme.spacingL)
            }
            modelStatusCard
                .padding(.bottom, Theme.spacingL)
            medicalNotice
        }
        .padding(.horizontal, Theme.pageMargin)
        // The same header-to-content step History and Settings use.
        .padding(.top, Theme.spacingL)
        .padding(.bottom, Theme.tabBarClearance)
    }

    private var earlierScansHeader: some View {
        HStack(alignment: .firstTextBaseline) {
            Text("Earlier scans")
                .ocrFont(.sectionHead)
                .tracking(-0.45)
                .foregroundStyle(Theme.textPrimary)
            Spacer(minLength: Theme.spacingM)
            Button {
                selectTab(.history)
            } label: {
                Text("See all")
                    .ocrFont(.listValue.size(15))
                    .foregroundStyle(Theme.accent)
                    // Enlarged touch target without disturbing the baseline the
                    // header is aligned on: 13 above and below an ~18pt line
                    // box clears 44, and the matching negative padding gives
                    // the extra height back to the layout.
                    .padding(.vertical, 13)
                    .padding(.leading, 12)
                    .contentShape(.rect)
                    .padding(.vertical, -13)
                    .padding(.leading, -12)
            }
            .buttonStyle(.plain)
        }
    }

    private var earlierScansRows: some View {
        VStack(spacing: Theme.spacingS) {
            ForEach(Array(records.dropFirst().prefix(2))) { record in
                Button {
                    detailRecord = record
                } label: {
                    earlierScanRowContent(record)
                    .padding(.vertical, Theme.spacingM)
                    .padding(.horizontal, 18)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .background(Theme.surface, in: .rect(cornerRadius: Theme.rowCorner))
                    .ocrTopEdgeHighlight(RoundedRectangle(cornerRadius: Theme.rowCorner))
                    .contentShape(.rect)
                }
                .buttonStyle(.plain)
                .accessibilityLabel(rowAccessibilityLabel(for: record))
                .accessibilityHint("Opens this scan's details.")
            }
        }
    }

    /// The row's three parts — numeral, title block, chevron — in the
    /// arrangement the reader's text size can actually hold.
    ///
    /// **Beside at reading sizes, above at accessibility sizes.** The design's
    /// row is a numeral column, a two-line title block and a chevron on one
    /// line. That line is only wide enough while the type is: at AX2 and up the
    /// three columns of chrome leave the title less width than one word of it
    /// needs, and because a row can only report the width its contents demand,
    /// the shortfall came back out as *the app* being too wide. So above
    /// `isAccessibilitySize` the numeral and the chevron take a line of their
    /// own and the text gets the full width of the card. The row grows
    /// downwards, which a scroll view can absorb; nothing grows sideways, which
    /// nothing can.
    @ViewBuilder
    private func earlierScanRowContent(_ record: ScanRecord) -> some View {
        let isStacked = dynamicTypeSize.isAccessibilitySize
        let layout = isStacked
            ? AnyLayout(VStackLayout(alignment: .leading, spacing: Theme.spacingS))
            : AnyLayout(HStackLayout(spacing: Theme.spacingM))

        layout {
            HStack(spacing: 0) {
                railNumeral(record)
                if isStacked {
                    Spacer(minLength: Theme.spacingS)
                    OCRChevron()
                }
            }
            VStack(alignment: .leading, spacing: 3) {
                Text(record.topClassName)
                    .ocrFont(.rowTitle)
                    .tracking(-0.2)
                    .foregroundStyle(Theme.textPrimary)
                // The shared meta run. The date stays the long
                // form the design pins for this screen against
                // History's short tokens; what is now shared is the
                // hierarchy the two tokens are set in.
                //
                // `isDemo` is passed from the record's own flag, as
                // History's row does. Omitting it let the parameter
                // default to `false`, so a demo record read "Moderate
                // risk · 1d" here and carried the salmon marker in
                // History — one honesty surface disagreeing with
                // another, and with this row's own VoiceOver label
                // below, which has always said ", demo result".
                OCRMetaLine(
                    tier: record.riskLevel.displayLabel,
                    timestamp: HomeFormat.relative(record.timestamp),
                    isDemo: record.isDemoResult
                )
            }
            .multilineTextAlignment(.leading)
            .frame(maxWidth: .infinity, alignment: .leading)
            if !isStacked {
                OCRChevron()
            }
        }
    }

    /// The confidence figure in its column. It scales with the text inside it
    /// and shrinks before it truncates — the same pattern the 52pt History
    /// avatar uses. A raw 52 turned "91" into "9…" from about AX1 upward; an
    /// unbounded one turned the row into something wider than the phone.
    private func railNumeral(_ record: ScanRecord) -> some View {
        Text("\(ConfidencePercent.value(record.probability))")
            .ocrFont(.screenTitle)
            .tracking(-1.0)
            .monospacedDigit()
            .lineLimit(1)
            .minimumScaleFactor(0.6)
            .foregroundStyle(Theme.numeralMuted)
            // Centred, not leading. History centres the same
            // datum in a 52pt avatar on the same 52pt column
            // against the same title rail, so a left-aligned
            // numeral here put the two screens' optical centres
            // 9.8pt apart and left 38pt of dead space before
            // the title where History has 17.7.
            .frame(
                width: min(railNumeralWidth, Self.railNumeralMaxWidth),
                alignment: dynamicTypeSize.isAccessibilitySize ? .leading : .center
            )
    }

    private func rowAccessibilityLabel(for record: ScanRecord) -> String {
        var label = "Scan from \(HomeFormat.relative(record.timestamp)): "
        label += "\(record.topClassName.lowercased()), "
        label += "\(ConfidencePercent.value(record.probability)) percent confidence, "
        label += record.riskLevel.displayLabel.lowercased()
        if record.isDemoResult {
            label += ", demo result"
        }
        return label
    }

    // MARK: - Confidence trend

    private var chartCard: some View {
        VStack(alignment: .leading, spacing: 0) {
            Text("Confidence over time")
                .ocrFont(.cardTitle)
                .tracking(-0.25)
                .foregroundStyle(Theme.textPrimary)
                .padding(.bottom, 2)
            Text("All \(records.count) scans")
                .ocrFont(.meta)
                .foregroundStyle(Theme.textSecondary)
                .padding(.bottom, 20)
            HomeConfidenceChart(points: chartPoints)
        }
        .padding(.vertical, 22)
        // 18, the one horizontal content inset every card and row in the app
        // uses. At 20 this card's title started 2pt right of the rail rows
        // stacked directly above it — too small to read as intentional, too
        // large to be invisible.
        .padding(.horizontal, 18)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Theme.surface, in: .rect(cornerRadius: Theme.panelCorner))
        .ocrTopEdgeHighlight(RoundedRectangle(cornerRadius: Theme.panelCorner))
    }

    /// Oldest first, so the line reads left to right.
    private var chartPoints: [HomeChartPoint] {
        records.reversed().map { record in
            HomeChartPoint(
                probability: record.probability,
                shortLabel: HomeFormat.shortToken(record.timestamp),
                longLabel: HomeFormat.relative(record.timestamp)
            )
        }
    }

    // MARK: - Model status

    /// Honesty rule 1: this branch is the single source of truth for whether
    /// the app claims a trained model. Every other surface reads the same way.
    private var modelStatusCard: some View {
        HStack(alignment: .top, spacing: 11) {
            OCRStatusDot(color: classifier.kind == .mock ? Theme.salmon : Theme.mint)
                .padding(.top, 5)
            modelStatusText
                .ocrFont(.meta)
                .ocrBodyLeading(size: 13.5)
                .fixedSize(horizontal: false, vertical: true)
                .frame(maxWidth: .infinity, alignment: .leading)
        }
        .padding(.vertical, Theme.spacingM)
        .padding(.horizontal, 18)
        .frame(maxWidth: .infinity, alignment: .leading)
        .overlay {
            // `Theme.noticeBorder`, not the literal `#2A2A2E` this used to
            // carry. That hex was picked against a pure-black canvas and was
            // the last neutral grey on Home: beside the violet ink around it
            // the card's outline read as a different material from every other
            // hairline in the app. It is the same outline the demo notice in
            // both sheets uses, which is exactly what this card is.
            RoundedRectangle(cornerRadius: Theme.rowCorner)
                .strokeBorder(Theme.noticeBorder, lineWidth: 1)
        }
        .accessibilityElement(children: .combine)
    }

    /// The two branches stay whole, separate strings — a build where this
    /// surface disagrees with Settings or the History meta is a defect.
    ///
    /// Built as one `AttributedString` rather than two concatenated `Text`s so
    /// the bold lead-in and the body read as a single flowing sentence; the
    /// detail run leaves its font unset so it inherits the caller's `ocrMeta`.
    private var modelStatusText: Text {
        let title: String
        let detail: String
        if classifier.kind == .mock {
            title = "Demo mode — no trained model installed."
            detail = " Results come from a deterministic stand-in so you can explore the app; they carry no medical meaning."
        } else {
            title = "Model \(classifier.manifest.modelVersion)"
            detail = " On-device Core ML model installed and ready."
        }
        var status = AttributedString(title)
        status.font = .system(size: metaFontSize, weight: .semibold)
        status.foregroundColor = Theme.textPrimary
        var rest = AttributedString(detail)
        rest.foregroundColor = Theme.textSecondary
        status.append(rest)
        return Text(status)
    }

    // MARK: - Medical notice

    /// The disclaimer, as the bordered red-framed object rather than the grey
    /// 13pt run of `textTertiary` that used to close the page.
    ///
    /// It was the last thing on the longest scroll in the app, set in the
    /// faintest ink the palette has, in the same paragraph shape as a caption —
    /// which is to say it was present and unread. `OCRMedicalNotice` gives it a
    /// warning glyph, a title that states the claim in four words, and a red
    /// outline that nothing else in the app has — at the one weight the
    /// component has, which matters here because Home carries no other warning:
    /// for a reader who never opens the Result sheet this is the only place the
    /// app says what it is not.
    ///
    /// The copy is `MedicalDisclaimer.short` verbatim — unchanged from the
    /// footnote this replaces, and never written here (honesty rule 4).
    ///
    /// # Both tap targets, not one
    ///
    /// The notice itself is now a button, so the whole object opens the full
    /// notice rather than a short run of link text buried at the end of a
    /// sentence. The explicit "Read the full notice" link is kept below it
    /// anyway, with its accent colour, its underline and its `linkURL` intact:
    /// it is the only *visible* statement that there is more to read, and a
    /// bordered panel that happens to be tappable does not say that on its own.
    /// VoiceOver gets the notice as one button — "Not a medical diagnosis,
    /// <the disclaimer>" — and the link as the link element it already was.
    private var medicalNotice: some View {
        VStack(alignment: .leading, spacing: Theme.spacingS) {
            Button {
                isShowingDisclaimer = true
            } label: {
                OCRMedicalNotice(MedicalDisclaimer.short)
                    // The notice paints its own fill, but the button's hit
                    // region should be the whole rounded rectangle including
                    // any slack, matching every other card-shaped button here.
                    .contentShape(.rect(cornerRadius: Theme.cardCorner))
            }
            .buttonStyle(.plain)
            .accessibilityHint("Opens the full medical disclaimer.")

            Text(fullNoticeLink)
                .ocrFont(.footnote)
                .ocrFootnoteLeading(size: 13)
                .fixedSize(horizontal: false, vertical: true)
                .environment(\.openURL, OpenURLAction { _ in
                    isShowingDisclaimer = true
                    return .handled
                })
        }
    }

    /// The "Read the full notice" link, styled and routed exactly as it was
    /// when it trailed the footnote: accent, underlined, carrying
    /// `MedicalDisclaimerSheet.linkURL`, and intercepted by the local
    /// `OpenURLAction` above so it never reaches the system.
    private var fullNoticeLink: AttributedString {
        var link = AttributedString("Read the full notice")
        link.foregroundColor = Theme.accent
        link.underlineStyle = Text.LineStyle.single
        link.link = MedicalDisclaimerSheet.linkURL
        return link
    }
}

// MARK: - Hero chrome

/// Liquid Glass for the hero's settings button — the one surface on Home that
/// qualifies. It *floats over* the gradient panel rather than being part of the
/// page, which is what the material is for, and the gradient gives it something
/// to refract; the flat cards below it sit on the ink canvas, which is far too
/// dark and far too even to give glass anything to work with — it would only
/// mud them.
///
/// Untinted, though the obvious move was to tint it with the `white 16%` the
/// flat fill used. Both were sampled on the simulator over the hero's `#81499C`:
/// the tinted circle lifted to `#AF7BC7` and the white glyph fell to **3.24:1**,
/// worse than the flat fill it replaced. Untinted it settles at `#9D5EB8` for
/// **4.4:1**, holding the flat treatment's contrast while the specular rim does
/// the work of saying "control". Regular glass over a mid-tone gradient already
/// brightens; a white tint only pushes it further toward the glyph.
///
/// With Reduce Transparency on it falls all the way back to the flat
/// `white 16%` fill.
///
/// No `glassEffectID` or morph here, so there is no motion to gate on Reduce
/// Motion — the button is a single static circle.
private struct HeroGlassCircle: ViewModifier {
    @Environment(\.accessibilityReduceTransparency) private var reduceTransparency

    func body(content: Content) -> some View {
        content.ocrGlass(
            .circle,
            interactive: true,
            fallback: .white.opacity(0.16),
            reduceTransparency: reduceTransparency
        )
    }
}

// MARK: - Chart

private struct HomeChartPoint {
    let probability: Double
    let shortLabel: String
    let longLabel: String

    var clamped: Double { min(max(probability, 0), 1) }
    var percent: Int { ConfidencePercent.value(probability) }
}

/// Area chart drawn by hand in the design's 310×120 coordinate space, scaled
/// uniformly to the card width. Axis labels are anchored to the data
/// x-coordinates — a distributed row drifts up to 33pt away from its point.
///
/// The plot keeps the geometric aspect-ratio box; the axis labels sit in a
/// sibling row below it whose height is driven by the text. Positioning them
/// absolutely *inside* the box (at the design's y 114 of 120) left ~5pt of
/// clearance below their centreline, so at large Dynamic Type sizes they grew
/// straight out of the chart frame and into the card beneath.
private struct HomeConfidenceChart: View {
    let points: [HomeChartPoint]

    private static let viewWidth: CGFloat = 310
    /// The plot area alone: the design's 120 tall box minus the axis band that
    /// the label row now provides for itself.
    private static let plotHeight: CGFloat = 106
    private static let firstX: CGFloat = 34
    private static let lastX: CGFloat = 276
    private static let baselineY: CGFloat = 104
    private static let amplitude: CGFloat = 78
    private static let labelFontSize: CGFloat = 11.5

    var body: some View {
        VStack(spacing: 1) {
            plot
            axisLabels
        }
        .accessibilityElement()
        .accessibilityLabel(accessibilityLabel)
    }

    private var plot: some View {
        GeometryReader { proxy in
            let scale = proxy.size.width / Self.viewWidth
            ZStack(alignment: .topLeading) {
                areaPath(scale: scale)
                    .fill(
                        LinearGradient(
                            colors: [Theme.accent.opacity(0.38), Theme.accent.opacity(0)],
                            startPoint: .top,
                            endPoint: .bottom
                        )
                    )
                linePath(scale: scale)
                    .stroke(
                        Theme.accent,
                        style: StrokeStyle(lineWidth: 2.25, lineCap: .round, lineJoin: .round)
                    )
                if let newest = points.last {
                    Circle()
                        // The design's `#000` core, which is now the ink floor.
                        // It is deliberately darker than the `surface` card it
                        // is drawn on — that is what makes the salmon ring read
                        // as a hollow marker punched through the area fill
                        // rather than as a filled dot sitting on top of it.
                        .fill(Theme.canvas)
                        .frame(width: 9, height: 9)
                        .overlay(Circle().stroke(Theme.salmon, lineWidth: 2.25))
                        .position(
                            x: x(at: points.count - 1) * scale,
                            y: y(for: newest.clamped) * scale
                        )
                }
            }
        }
        .frame(maxWidth: .infinity)
        .aspectRatio(Self.viewWidth / Self.plotHeight, contentMode: .fit)
    }

    /// A hidden digit in the label font gives the row exactly one scaled line
    /// of height; the visible labels are then centred over the same data
    /// x-coordinates the plot uses.
    private var axisLabels: some View {
        Text(verbatim: "0")
            .font(.system(size: Self.labelFontSize))
            .hidden()
            .frame(maxWidth: .infinity)
            .overlay {
                GeometryReader { proxy in
                    let scale = proxy.size.width / Self.viewWidth
                    ForEach(labelledIndices, id: \.self) { index in
                        Text(points[index].shortLabel)
                            .font(.system(size: Self.labelFontSize))
                            // "1h" / "1d" / "5d" read across one row and are
                            // compared against each other.
                            .monospacedDigit()
                            .foregroundStyle(
                                index == points.count - 1
                                    ? Theme.textPrimary
                                    : Theme.textSecondary
                            )
                            .fixedSize()
                            .position(
                                x: x(at: index) * scale,
                                y: proxy.size.height / 2
                            )
                    }
                }
            }
    }

    private func x(at index: Int) -> CGFloat {
        guard points.count > 1 else { return (Self.firstX + Self.lastX) / 2 }
        let step = (Self.lastX - Self.firstX) / CGFloat(points.count - 1)
        return Self.firstX + step * CGFloat(index)
    }

    private func y(for probability: Double) -> CGFloat {
        Self.baselineY - CGFloat(probability) * Self.amplitude
    }

    private func linePath(scale: CGFloat) -> Path {
        Path { path in
            for (index, point) in points.enumerated() {
                let location = CGPoint(x: x(at: index) * scale, y: y(for: point.clamped) * scale)
                if index == 0 {
                    path.move(to: location)
                } else {
                    path.addLine(to: location)
                }
            }
        }
    }

    private func areaPath(scale: CGFloat) -> Path {
        Path { path in
            guard !points.isEmpty else { return }
            let baseline = Self.baselineY * scale
            path.move(to: CGPoint(x: x(at: 0) * scale, y: baseline))
            for (index, point) in points.enumerated() {
                path.addLine(to: CGPoint(x: x(at: index) * scale, y: y(for: point.clamped) * scale))
            }
            path.addLine(to: CGPoint(x: x(at: points.count - 1) * scale, y: baseline))
            path.closeSubpath()
        }
    }

    /// Every point is labelled while the axis has room; beyond three scans the
    /// labels would collide, so only the ends and the middle are drawn — still
    /// anchored to real data x-coordinates. VoiceOver always gets them all.
    private var labelledIndices: [Int] {
        guard points.count > 3 else { return Array(points.indices) }
        return [0, points.count / 2, points.count - 1]
    }

    private var accessibilityLabel: String {
        let values = points
            .map { "\($0.percent) percent \($0.longLabel)" }
            .joined(separator: ", ")
        return "Top-class confidence: \(values)."
    }
}

// MARK: - Disclaimer sheet


// MARK: - Formatting

private enum HomeFormat {
    /// "1 hour ago", "yesterday", "5 days ago" — the same style the History
    /// rows and the detail sheet use.
    static func relative(_ date: Date) -> String {
        date.formatted(.relative(presentation: .named))
    }

    /// Short axis token — "1h", "1d", "5d". Long forms overflow the chart.
    ///
    /// Shared with the History meta column rather than reimplemented, so the
    /// axis and the rows can never disagree about the same record's age.
    static func shortToken(_ date: Date) -> String {
        RelativeToken.short(for: date)
    }
}

// MARK: - Previews

private enum HomePreviewData {
    /// The three scans the design was measured against.
    static func seededContainer(recordCount: Int) -> ModelContainer? {
        let configuration = ModelConfiguration(isStoredInMemoryOnly: true)
        guard let container = try? ModelContainer(
            for: ScanRecord.self,
            configurations: configuration
        ) else { return nil }
        let seeds: [(String, String, RiskLevel, Double, TimeInterval)] = [
            ("healthy", "No visible lesion", .low, 0.91, -3_600),
            ("leukoplakia", "Leukoplakia", .moderate, 0.64, -90_000),
            ("erythroplakia", "Erythroplakia", .high, 0.55, -400_000),
        ]
        for (id, name, risk, probability, offset) in seeds.prefix(recordCount) {
            container.mainContext.insert(
                ScanRecord(
                    timestamp: .now.addingTimeInterval(offset),
                    topClassID: id,
                    topClassName: name,
                    riskLevel: risk,
                    probability: probability,
                    modelVersion: "mock-0.0.0"
                )
            )
        }
        return container
    }
}

#Preview("Home — three scans") {
    if let container = HomePreviewData.seededContainer(recordCount: 3) {
        HomeView()
            .environment(\.lesionClassifier, MockLesionClassifier())
            .modelContainer(container)
            .preferredColorScheme(.dark)
    }
}

#Preview("Home — no scans") {
    if let container = HomePreviewData.seededContainer(recordCount: 0) {
        HomeView()
            .environment(\.lesionClassifier, MockLesionClassifier())
            .modelContainer(container)
            .preferredColorScheme(.dark)
    }
}
