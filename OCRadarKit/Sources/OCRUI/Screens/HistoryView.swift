import OCRCore
import SwiftData
import SwiftUI
import UIKit

/// History tab (design §3): every saved scan grouped by real month, newest
/// first, with a detail sheet per record and swipe-to-delete.
struct HistoryView: View {
    @Query(sort: \ScanRecord.timestamp, order: .reverse) private var records: [ScanRecord]
    @Environment(\.modelContext) private var modelContext
    /// Installed by `RootView` so screens can drive the floating tab bar.
    /// `RootView` owns the selection and publishes a setter rather than a
    /// binding, which is the same key Home and Settings navigate through.
    @Environment(\.selectTab) private var selectTab

    @State private var detailRecord: ScanRecord?

    var body: some View {
        Group {
            if records.isEmpty {
                emptyState
            } else {
                recordList
            }
        }
        .background(Theme.canvas)
        .sheet(item: $detailRecord) { record in
            HistoryDetailView(record: record)
                .presentationCornerRadius(Theme.sheetCorner)
                .presentationBackground(Theme.canvas)
        }
    }

    // MARK: - Header

    private var header: some View {
        OCRHeaderBand(title: "History", subtitle: "Saved on this device only") {
            Text(countLabel)
        }
    }

    /// "3 scans" / "1 scan" / "No scans".
    private var countLabel: String {
        switch records.count {
        case 0: "No scans"
        case 1: "1 scan"
        default: "\(records.count) scans"
        }
    }

    // MARK: - Populated state

    /// A `List` rather than a `LazyVStack` so swipe-to-delete stays a real
    /// system affordance (and stays reachable from the VoiceOver Actions
    /// rotor). All list chrome is stripped so the rows read as the design's
    /// free-standing cards.
    private var recordList: some View {
        List {
            header
                .listRowInsets(EdgeInsets())
                .listRowBackground(Color.clear)
                .listRowSeparator(.hidden)

            ForEach(monthGroups) { group in
                OCRSectionLabel(group.title)
                    .padding(.top, Theme.spacingL)
                    .padding(.bottom, 12)
                    .listRowInsets(EdgeInsets(top: 0, leading: Theme.pageMargin, bottom: 0, trailing: Theme.pageMargin))
                    .listRowBackground(Color.clear)
                    .listRowSeparator(.hidden)

                ForEach(group.records) { record in
                    Button {
                        detailRecord = record
                    } label: {
                        HistoryRow(record: record, isNewest: record.persistentModelID == newestID)
                    }
                    .buttonStyle(.plain)
                    .listRowInsets(EdgeInsets(top: 0, leading: Theme.pageMargin, bottom: Theme.spacingS, trailing: Theme.pageMargin))
                    .listRowBackground(Color.clear)
                    .listRowSeparator(.hidden)
                    .swipeActions(edge: .trailing) {
                        Button(role: .destructive) {
                            delete(record)
                        } label: {
                            Label("Delete", systemImage: "trash")
                        }
                    }
                }
            }

            Text("Deleting a scan removes it permanently.")
                .font(.ocrFootnote())
                .lineSpacing(4)
                .foregroundStyle(Theme.textTertiary)
                .padding(.top, 12)
                .padding(.bottom, 130)
                .listRowInsets(EdgeInsets(top: 0, leading: Theme.pageMargin, bottom: 0, trailing: Theme.pageMargin))
                .listRowBackground(Color.clear)
                .listRowSeparator(.hidden)
        }
        .listStyle(.plain)
        .environment(\.defaultMinListRowHeight, 0)
        .scrollContentBackground(.hidden)
        .scrollIndicators(.hidden)
        .ocrQAScrollBottom()
        // Gradient band at the top, floating tab bar at the bottom: the top
        // edge effect stays off at rest and returns once the list scrolls, the
        // bottom one is soft. The 130pt padding on the footnote below still
        // does the reaching.
        .ocrScrollEdges()
    }

    /// The newest record overall — its avatar carries the button gradient.
    private var newestID: PersistentIdentifier? { records.first?.persistentModelID }

    // MARK: - Empty state

    /// Restyled empty state (design §3) — deliberately not
    /// `ContentUnavailableView`, whose system chrome fights the flat dark canvas.
    private var emptyState: some View {
        ScrollView {
            VStack(spacing: 0) {
                header

                VStack(spacing: 0) {
                    // `dashedMiddle` is the empty-state variant: solid outer
                    // ring, dashed middle ring, and the `#4A4A52` centre dot,
                    // all drawn by `OCRRadar` itself.
                    OCRRadar(diameter: 66, sweeping: false, dashedMiddle: true)
                        .accessibilityHidden(true)
                        .padding(.bottom, 22)

                    Text("No scans yet")
                        .font(.ocrSectionHead())
                        .tracking(-0.45)
                        .foregroundStyle(Theme.textPrimary)
                        .padding(.bottom, Theme.spacingS)

                    Text("Photos you analyze in the Scan tab are saved here, on this device only.")
                        .font(.ocrBody())
                        .lineSpacing(4)
                        .foregroundStyle(Theme.textSecondary)
                        .multilineTextAlignment(.center)
                        .padding(.bottom, Theme.pageMargin)

                    Button {
                        selectTab(.scan)
                    } label: {
                        Label("Take your first scan", systemImage: "camera.fill")
                    }
                    .buttonStyle(OCRPrimaryButtonStyle(height: 50))
                    .frame(maxWidth: 300)
                }
                .padding(.horizontal, Theme.pageMargin)
                .padding(.top, 80)
                .padding(.bottom, 130)
            }
        }
        .scrollIndicators(.hidden)
        .ocrScrollEdges()
    }

    // MARK: - Grouping

    /// Records bucketed by the calendar month they were taken in, most recent
    /// month first. Derived from `timestamp`, never hardcoded — a library that
    /// spans a year renders a heading per month.
    private var monthGroups: [MonthGroup] {
        var order: [MonthKey] = []
        var buckets: [MonthKey: [ScanRecord]] = [:]
        let calendar = Calendar.current

        for record in records {
            let parts = calendar.dateComponents([.year, .month], from: record.timestamp)
            let key = MonthKey(year: parts.year ?? 0, month: parts.month ?? 0)
            if buckets[key] == nil {
                order.append(key)
                buckets[key] = []
            }
            buckets[key]?.append(record)
        }

        // `records` is already newest-first, so first-seen order is newest-first.
        return order.map { key in
            let members = buckets[key] ?? []
            let title = members.first?.timestamp.formatted(.dateTime.month(.wide).year()) ?? ""
            return MonthGroup(id: key, title: title, records: members)
        }
    }

    private struct MonthKey: Hashable {
        let year: Int
        let month: Int
    }

    private struct MonthGroup: Identifiable {
        let id: MonthKey
        let title: String
        let records: [ScanRecord]
    }

    // MARK: - Deletion

    private func delete(_ record: ScanRecord) {
        modelContext.delete(record)
        // Persist the deletion immediately so it cannot be resurrected by an
        // unflushed context if the app is killed right after the swipe.
        try? modelContext.save()
    }
}

// MARK: - Row

/// One saved scan: a 52pt confidence avatar, the class name, and a
/// "<Tier> risk · Demo · 1h" meta line.
private struct HistoryRow: View {
    let record: ScanRecord
    /// The newest record overall wears the button gradient; older ones are flat.
    let isNewest: Bool

    @ScaledMetric(relativeTo: .body) private var avatar: CGFloat = 52

    var body: some View {
        HStack(spacing: Theme.spacingM) {
            avatarView
            VStack(alignment: .leading, spacing: 3) {
                Text(record.topClassName)
                    .font(.ocrRowTitle())
                    .tracking(-0.2)
                    .foregroundStyle(Theme.textPrimary)
                    .lineLimit(2)
                Text(metaText)
                    .font(.ocrMeta())
                    .foregroundStyle(Theme.textSecondary)
                    .lineLimit(1)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            Image(systemName: "chevron.right")
                .font(.system(size: 15, weight: .semibold))
                .foregroundStyle(Theme.chevron)
                .accessibilityHidden(true)
        }
        .padding(.vertical, Theme.spacingM)
        .padding(.horizontal, 18)
        .frame(minHeight: Theme.minTarget)
        .background(Theme.surface, in: .rect(cornerRadius: Theme.rowCorner))
        .contentShape(.rect(cornerRadius: Theme.rowCorner))
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(accessibilityText)
        .accessibilityAddTraits(.isButton)
    }

    private var avatarView: some View {
        Text(percentValue.formatted())
            .font(.system(size: 17, weight: .semibold))
            .monospacedDigit()
            .minimumScaleFactor(0.6)
            .lineLimit(1)
            .foregroundStyle(isNewest ? Theme.onGradient() : Theme.numeralMuted)
            .frame(width: avatar, height: avatar)
            .background {
                if isNewest {
                    Theme.button.clipShape(.circle)
                } else {
                    Circle().fill(Theme.surfaceRaised)
                }
            }
            .accessibilityHidden(true)
    }

    /// "<Tier> risk · Demo · 1h" — the "Demo" token appears only for records
    /// produced by the stand-in classifier, so a demo scan can never read as
    /// real analysis in a later build that ships a trained model.
    private var metaText: String {
        var parts = [record.riskLevel.displayLabel]
        if record.isDemoResult {
            parts.append("Demo")
        }
        parts.append(RelativeToken.short(for: record.timestamp))
        return parts.joined(separator: " · ")
    }

    private var percentValue: Int {
        ConfidencePercent.value(record.probability)
    }

    /// A full sentence, so VoiceOver never reads a bare numeral. Demo records
    /// say so out loud — the visual "Demo" token would otherwise be lost.
    private var accessibilityText: String {
        let when = record.timestamp.formatted(.relative(presentation: .named))
        let tier = record.riskLevel.displayLabel.lowercased()
        let base = "Scan from \(when): \(record.topClassName.lowercased()), \(percentValue) percent confidence, \(tier)"
        return record.isDemoResult ? "\(base), demo result." : "\(base)."
    }
}

// MARK: - Relative tokens

/// Short relative date tokens for the History meta column. Longer forms
/// ("2 days ago") wrap the 226pt column and make row heights uneven, so the
/// design measured and pinned these.
enum RelativeToken {
    /// Units are **rounded**, not truncated, so the short token agrees with
    /// the long form beside it. Truncating made the oldest seeded scan — 4.63
    /// days old — read "5 days ago" in the Home row and "4d" in the History
    /// meta and on the chart axis, for one and the same record.
    /// Each unit is rounded *before* its range is tested, never after. Testing
    /// the raw value and printing the rounded one emitted tokens outside their
    /// own unit — "60m" for anything from 59.5 minutes and "24h" from 23.5
    /// hours — which is the same disagreement with the long form the rounding
    /// was introduced to remove.
    static func short(for date: Date, now: Date = .now) -> String {
        let seconds = now.timeIntervalSince(date)
        guard seconds >= 60 else { return "now" }

        let minutes = (seconds / 60).rounded()
        if minutes < 60 { return "\(Int(minutes))m" }

        let hours = (seconds / 3_600).rounded()
        if hours < 24 { return "\(Int(hours))h" }

        let days = (seconds / 86_400).rounded()
        if days <= 7 { return "\(Int(days))d" }

        if days < 365 { return "\(Int((seconds / 604_800).rounded()))w" }
        return "\(Int((seconds / 31_536_000).rounded()))y"
    }
}

// MARK: - Detail sheet

/// Detail sheet for one saved scan (design §6). Every value is read from the
/// tapped record — its own class, confidence, tier, model and timestamp — so
/// the sheet always matches the row that opened it.
///
/// Deliberately no class breakdown: a stored record keeps only its top class,
/// and a full score table belongs to a fresh analysis (`ResultView`).
struct HistoryDetailView: View {
    let record: ScanRecord

    @Environment(\.dismiss) private var dismiss

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 0) {
                OCRSheetHeader(
                    eyebrow: "Scan detail",
                    meta: record.timestamp.formatted(.relative(presentation: .named)),
                    percentText: percentText,
                    title: record.topClassName,
                    tierText: record.riskLevel.displayLabel,
                    onDone: { dismiss() }
                )

                VStack(alignment: .leading, spacing: 18) {
                    if record.isDemoResult {
                        demoNotice
                            .padding(.bottom, 4)
                    }

                    detailCard

                    // Below the rows, not above them: the design's order for
                    // this sheet is notice → rows → footnote, and a full-width
                    // photo between the notice and the rows pushed every
                    // measured value off the first screen.
                    scanImage

                    Text(MedicalDisclaimer.full)
                        .font(.ocrFootnote())
                        .lineSpacing(4)
                        .foregroundStyle(Theme.textTertiary)
                }
                .padding(.horizontal, Theme.pageMargin)
                .padding(.top, Theme.pageMargin)
                .padding(.bottom, 44)
            }
        }
        .scrollIndicators(.hidden)
        // Sheet, so no tab bar and no status-bar overlap: only the bottom edge
        // is worth softening, and the body's 44pt bottom padding keeps the
        // disclaimer clear of the dissolve.
        .scrollEdgeEffectStyle(.soft, for: .bottom)
        .background(Theme.canvas)
    }

    private var percentText: String {
        ConfidencePercent.text(record.probability)
    }

    /// Clear notice that this saved scan came from the demo stand-in
    /// classifier, so an old mock record can never read as real analysis —
    /// even in a later build that ships a trained model. This wording is the
    /// detail sheet's own; `ResultView` speaks about a result being generated
    /// right now, which would be wrong for a stored record.
    private var demoNotice: some View {
        OCRDemoNotice(
            title: "Demo result.",
            message: "This scan was made without a trained model. Its scores are generated placeholders and carry no medical meaning."
        )
    }

    /// Four 54pt rows. `Model` reads the version stored *on the record*, not
    /// the classifier currently installed, so history stays truthful across
    /// builds.
    private var detailCard: some View {
        VStack(spacing: 0) {
            detailRow("Confidence", percentText, monospaced: true)
            rowDivider
            detailRow("Risk tier", record.riskLevel.displayLabel)
            rowDivider
            detailRow("Model", modelLabel)
            rowDivider
            detailRow("Scanned", scannedLabel)
        }
        .background(Theme.surface, in: .rect(cornerRadius: Theme.cardCorner))
    }

    private var modelLabel: String {
        record.isDemoResult ? "Demo (\(record.modelVersion))" : record.modelVersion
    }

    /// The date and time this scan was taken, as a compact field skeleton:
    /// abbreviated month, numeric day and year, hour and minute, no seconds
    /// and no weekday. `Date.FormatStyle` resolves that skeleton against the
    /// locale, so the *order* and separators are the locale's — en_US reads
    /// "Aug 17, 2026 at 8:41 AM", en_GB "17 Aug 2026 at 08:41". Chaining the
    /// fields in a different sequence would not change it, and it is not a
    /// fixed token; the row is kept to one line by `detailRow`'s
    /// `lineLimit(1)` + `minimumScaleFactor`, not by this string's length.
    private var scannedLabel: String {
        record.timestamp.formatted(
            .dateTime.day().month(.abbreviated).year().hour().minute()
        )
    }

    private func detailRow(_ label: String, _ value: String, monospaced: Bool = false) -> some View {
        HStack(spacing: 0) {
            Text(label)
                .font(.system(size: 16))
                .foregroundStyle(Theme.textSecondary)
                .layoutPriority(0)
            // The value wins the row: the label is short and fixed, so letting
            // it claim `maxWidth: .infinity` was what squeezed "Scanned" onto
            // two lines. All four rows now measure a flat 54.
            Spacer(minLength: Theme.spacingM)
            Text(value)
                .font(.system(size: 16))
                .monospacedDigit()
                .foregroundStyle(Theme.textPrimary)
                .multilineTextAlignment(.trailing)
                .lineLimit(1)
                .minimumScaleFactor(0.75)
                .layoutPriority(1)
        }
        .padding(.horizontal, 18)
        .frame(minHeight: Theme.rowHeight)
        .accessibilityElement(children: .combine)
    }

    private var rowDivider: some View {
        Rectangle()
            .fill(Theme.divider)
            .frame(height: 1)
            .padding(.leading, 18)
            .accessibilityHidden(true)
    }

    /// The saved photo, when the record kept one. Preserved from the previous
    /// build — the detail sheet is the only place a stored scan's image can be
    /// seen again.
    @ViewBuilder
    private var scanImage: some View {
        if let data = record.thumbnailData, let uiImage = UIImage(data: data) {
            Image(uiImage: uiImage)
                .resizable()
                .scaledToFit()
                .frame(maxWidth: .infinity)
                .clipShape(.rect(cornerRadius: Theme.panelCorner))
                .accessibilityLabel("Saved scan photo")
        }
    }
}

#Preview("History") {
    let configuration = ModelConfiguration(isStoredInMemoryOnly: true)
    if let container = try? ModelContainer(for: ScanRecord.self, configurations: configuration) {
        let _ = insertSampleRecords(into: container)
        HistoryView()
            .modelContainer(container)
            .environment(\.lesionClassifier, MockLesionClassifier())
            .preferredColorScheme(.dark)
    }
}

#Preview("History — empty") {
    let configuration = ModelConfiguration(isStoredInMemoryOnly: true)
    if let container = try? ModelContainer(for: ScanRecord.self, configurations: configuration) {
        HistoryView()
            .modelContainer(container)
            .environment(\.lesionClassifier, MockLesionClassifier())
            .preferredColorScheme(.dark)
    }
}

#Preview("Scan detail") {
    let configuration = ModelConfiguration(isStoredInMemoryOnly: true)
    if let container = try? ModelContainer(for: ScanRecord.self, configurations: configuration) {
        let record = ScanRecord(
            timestamp: .now.addingTimeInterval(-90_000),
            topClassID: "leukoplakia",
            topClassName: "Leukoplakia",
            riskLevel: .moderate,
            probability: 0.64,
            modelVersion: "mock-0.0.0",
            thumbnailData: nil
        )
        let _ = container.mainContext.insert(record)
        HistoryDetailView(record: record)
            .modelContainer(container)
            .environment(\.lesionClassifier, MockLesionClassifier())
            .preferredColorScheme(.dark)
    }
}

/// Seeds the in-memory preview container with a spread of risk tiers.
private func insertSampleRecords(into container: ModelContainer) {
    let context = container.mainContext
    context.insert(ScanRecord(
        timestamp: .now.addingTimeInterval(-3_600),
        topClassID: "healthy",
        topClassName: "No visible lesion",
        riskLevel: .low,
        probability: 0.91,
        modelVersion: "mock-0.0.0",
        thumbnailData: nil
    ))
    context.insert(ScanRecord(
        timestamp: .now.addingTimeInterval(-90_000),
        topClassID: "leukoplakia",
        topClassName: "Leukoplakia",
        riskLevel: .moderate,
        probability: 0.64,
        modelVersion: "mock-0.0.0",
        thumbnailData: makeSampleThumbnailData(color: .systemPurple)
    ))
    context.insert(ScanRecord(
        timestamp: .now.addingTimeInterval(-400_000),
        topClassID: "erythroplakia",
        topClassName: "Erythroplakia",
        riskLevel: .high,
        probability: 0.55,
        modelVersion: "mock-0.0.0",
        thumbnailData: makeSampleThumbnailData(color: .systemRed)
    ))
    // An older month, so the month grouping is visible in the preview.
    context.insert(ScanRecord(
        timestamp: .now.addingTimeInterval(-86_400 * 45),
        topClassID: "lichen-planus",
        topClassName: "Oral lichen planus",
        riskLevel: .moderate,
        probability: 0.38,
        modelVersion: "mock-0.0.0",
        thumbnailData: nil
    ))
}

/// Renders a flat-color JPEG stand-in thumbnail for preview records.
private func makeSampleThumbnailData(color: UIColor) -> Data? {
    let size = CGSize(width: 240, height: 240)
    let format = UIGraphicsImageRendererFormat()
    format.scale = 1
    let renderer = UIGraphicsImageRenderer(size: size, format: format)
    return renderer.jpegData(withCompressionQuality: 0.8) { context in
        color.withAlphaComponent(0.7).setFill()
        context.fill(CGRect(origin: .zero, size: size))
    }
}
