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
    /// still fits its column at accessibility text sizes.
    @ScaledMetric(relativeTo: .body) private var railNumeralWidth: CGFloat = 52

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 0) {
                hero
                pageBody
            }
        }
        .scrollIndicators(.hidden)
        .ocrQAScrollBottom()
        .background(Theme.canvas)
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
                    Image(systemName: "camera.fill")
                        .font(.system(size: 20))
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
        .foregroundStyle(.white)
    }

    /// Two concentric outlines bleeding off the top-right corner — they echo
    /// the radar rings in the app mark.
    private var decorativeRings: some View {
        ZStack(alignment: .topTrailing) {
            // Fills the hero so both rings anchor to its top-right corner.
            Color.clear
            Circle()
                .strokeBorder(.white.opacity(0.14), lineWidth: 1)
                .frame(width: 230, height: 230)
                .offset(x: 70, y: -40)
            Circle()
                .strokeBorder(.white.opacity(0.14), lineWidth: 1)
                .frame(width: 130, height: 130)
                .offset(x: 20, y: 10)
        }
        .accessibilityHidden(true)
    }

    private var wordmarkRow: some View {
        HStack(spacing: 9) {
            logoMark
            Text("OCRadar")
                .font(.ocrCardTitle())
                .tracking(-0.2)
            Spacer(minLength: Theme.spacingM)
            Button {
                selectTab(.settings)
            } label: {
                Image(systemName: "gearshape.fill")
                    .font(.system(size: 19))
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
                    .font(.system(size: 13.5, weight: .medium))
                    .foregroundStyle(Theme.onGradient())
                    .padding(.bottom, 12)
                // Same guard the sheet header carries: the 76pt numeral scales
                // with Dynamic Type and the hero clips its own bounds, so it
                // has to shrink rather than run under the panel edge.
                Text(ConfidencePercent.text(record.probability))
                    .font(.ocrHeroNumeral())
                    .tracking(-3.6)
                    .monospacedDigit()
                    .lineLimit(1)
                    .minimumScaleFactor(0.4)
                    .ocrHeroLineHeight()
                    .padding(.bottom, 10)
                Text(record.topClassName)
                    .font(.ocrScreenTitle())
                    .tracking(-0.7)
                    .fixedSize(horizontal: false, vertical: true)
                    .padding(.bottom, 6)
                Text(tierLine(for: record))
                    .font(.system(size: 15.5))
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
                .font(.ocrScreenTitle())
                .tracking(-0.7)
            Text("Take your first scan to see your results here.")
                .font(.system(size: 15.5))
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

    private var pageBody: some View {
        VStack(alignment: .leading, spacing: 0) {
            // The newest record is the hero, so the list and the trend only
            // have something to say from the second record onwards.
            if records.count >= 2 {
                earlierScansHeader
                    .padding(.bottom, 14)
                earlierScansRows
                    .padding(.bottom, Theme.spacingXL)
                chartCard
                    .padding(.bottom, 22)
            }
            modelStatusCard
                .padding(.bottom, Theme.spacingM)
            footnote
        }
        .padding(.horizontal, Theme.pageMargin)
        .padding(.top, Theme.spacingXL)
        // Clears the floating tab bar (62 tall, 30 from the bottom).
        .padding(.bottom, 130)
    }

    private var earlierScansHeader: some View {
        HStack(alignment: .firstTextBaseline) {
            Text("Earlier scans")
                .font(.ocrSectionHead())
                .tracking(-0.45)
                .foregroundStyle(Theme.textPrimary)
            Spacer(minLength: Theme.spacingM)
            Button {
                selectTab(.history)
            } label: {
                Text("See all")
                    .font(.system(size: 15))
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
                    HStack(spacing: Theme.spacingM) {
                        // The numeral column scales with the text inside it and
                        // shrinks before it truncates — the same pattern the
                        // 52pt History avatar uses. A raw 52 turned "91" into
                        // "9…" from about AX1 upward.
                        Text("\(ConfidencePercent.value(record.probability))")
                            .font(.ocrScreenTitle())
                            .tracking(-1.0)
                            .monospacedDigit()
                            .lineLimit(1)
                            .minimumScaleFactor(0.6)
                            .foregroundStyle(Theme.numeralMuted)
                            .frame(width: railNumeralWidth, alignment: .leading)
                        VStack(alignment: .leading, spacing: 3) {
                            Text(record.topClassName)
                                .font(.ocrRowTitle())
                                .tracking(-0.2)
                                .foregroundStyle(Theme.textPrimary)
                            Text("\(record.riskLevel.displayLabel) · \(HomeFormat.relative(record.timestamp))")
                                .font(.ocrMeta())
                                .foregroundStyle(Theme.textSecondary)
                        }
                        .multilineTextAlignment(.leading)
                        Spacer(minLength: Theme.spacingS)
                        Image(systemName: "chevron.right")
                            .font(.system(size: 20))
                            .foregroundStyle(Theme.chevron)
                            .accessibilityHidden(true)
                    }
                    .padding(.vertical, Theme.spacingM)
                    .padding(.horizontal, 18)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .background(Theme.surface, in: .rect(cornerRadius: Theme.rowCorner))
                    .contentShape(.rect)
                }
                .buttonStyle(.plain)
                .accessibilityLabel(rowAccessibilityLabel(for: record))
                .accessibilityHint("Opens this scan's details.")
            }
        }
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
                .font(.ocrCardTitle())
                .tracking(-0.25)
                .foregroundStyle(Theme.textPrimary)
                .padding(.bottom, 2)
            Text("All \(records.count) scans")
                .font(.ocrMeta())
                .foregroundStyle(Theme.textSecondary)
                .padding(.bottom, 20)
            HomeConfidenceChart(points: chartPoints)
        }
        .padding(.vertical, 22)
        .padding(.horizontal, 20)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Theme.surface, in: .rect(cornerRadius: Theme.panelCorner))
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
                .font(.ocrMeta())
                .lineSpacing(3)
                .fixedSize(horizontal: false, vertical: true)
                .frame(maxWidth: .infinity, alignment: .leading)
        }
        .padding(.vertical, Theme.spacingM)
        .padding(.horizontal, 18)
        .frame(maxWidth: .infinity, alignment: .leading)
        .overlay {
            RoundedRectangle(cornerRadius: Theme.rowCorner)
                .strokeBorder(Color(hex: 0x2A2A2E), lineWidth: 1)
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
        status.font = .ocrMeta().weight(.semibold)
        status.foregroundColor = Theme.textPrimary
        var rest = AttributedString(detail)
        rest.foregroundColor = Theme.textSecondary
        status.append(rest)
        return Text(status)
    }

    // MARK: - Footnote

    private var footnote: some View {
        Text(footnoteText)
            .font(.ocrFootnote())
            .lineSpacing(4)
            .fixedSize(horizontal: false, vertical: true)
            .environment(\.openURL, OpenURLAction { _ in
                isShowingDisclaimer = true
                return .handled
            })
    }

    /// `MedicalDisclaimer.short` verbatim, with the full notice one tap away.
    private var footnoteText: AttributedString {
        var text = AttributedString(MedicalDisclaimer.short + " ")
        text.foregroundColor = Theme.textTertiary
        var link = AttributedString("Read the full notice")
        link.foregroundColor = Theme.accent
        link.underlineStyle = Text.LineStyle.single
        link.link = MedicalDisclaimerSheet.linkURL
        return text + link
    }
}

// MARK: - Hero chrome

/// Liquid Glass for the hero's settings button — the one surface on Home that
/// qualifies. It *floats over* the gradient panel rather than being part of the
/// page, which is what the material is for, and the gradient gives it something
/// to refract; the flat cards below it sit on true black, where glass has
/// nothing to work with and would only mud them.
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
