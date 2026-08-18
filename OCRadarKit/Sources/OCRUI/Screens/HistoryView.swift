import OCRCore
import SwiftData
import SwiftUI
import UIKit

/// History tab (design §3): every saved comparison grouped by real month,
/// newest first, with a detail sheet per record and swipe-to-delete.
///
/// The list is the one results surface that deliberately carries **no** notice
/// of its own. A row is a compact reference back to a comparison, not the
/// comparison itself; the frame is set once, in the band's subtitle, and the
/// full statement lives on the detail sheet a row opens. A red panel wedged
/// between every pair of rows would be the definition of overdoing it, and the
/// reader who has learned to scroll past it is the reader who will also scroll
/// past it on the sheet where it matters.
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
        .background { OCRAmbientBackground() }
        .sheet(item: $detailRecord) { record in
            HistoryDetailView(record: record)
                .presentationCornerRadius(Theme.sheetCorner)
                .presentationBackground(Theme.canvas)
        }
    }

    // MARK: - Header

    /// The subtitle carries three facts, and all three are load-bearing: what
    /// these rows are (*comparisons*, not findings), what the numeral in each
    /// row's avatar means (how similar the photo looked, not how certain
    /// anything is), and where they live (this device, nowhere else). It is the
    /// whole of the framing this screen needs, which is why nothing below
    /// repeats it.
    ///
    /// "Past comparisons, saved on this device only" until this pass. It named
    /// the rows but not the number, and a bare numeral beside a category name is
    /// the one arrangement `ResultView` singles out as reading like diagnostic
    /// certainty. Naming it in the band costs a few words once, where prefixing
    /// every row would cost the category name its width — see `HistoryRow`.
    private var header: some View {
        OCRHeaderBand(
            title: "History",
            subtitle: "Past comparisons — closest reference category and how similar it looked. Saved on this device only."
        ) {
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
    ///
    /// The stripping is deliberately exhaustive, because a `List` is the one
    /// place in this app where Apple's default dark styling can leak back in
    /// and it leaks in as *grey*, which against the violet ink is instantly
    /// visible as borrowed chrome. Four separate things had to go and all four
    /// are still gone:
    ///
    /// - the **container background** (`scrollContentBackground(.hidden)`), so
    ///   the ambient plane behind the screen is what shows;
    /// - the **cell fill** (`listRowBackground(Color.clear)` on every row,
    ///   header and footnote included) — this is also what the swipe reveals as
    ///   a row slides, so a missed one would flash grey mid-gesture;
    /// - **separators** (`listRowSeparator(.hidden)` on every row). There are no
    ///   `Section`s, so there are no section separators to chase;
    /// - the **44pt minimum row height** (`defaultMinListRowHeight`), which
    ///   otherwise pads the section labels away from their groups.
    ///
    /// Nothing here touches `swipeActions`, which is the entire reason this is
    /// a `List` in the first place.
    private var recordList: some View {
        List {
            header
                // `ocrPanelSpill` draws 36pt of the band's own light *below*
                // the band. Every other screen puts its band in a `ScrollView`
                // or a `ZStack`, where that overhang renders freely; a `List`
                // clips a row to its own bounds, so here the row has to reserve
                // the space or History keeps exactly the hard chromatic cut the
                // spill exists to remove — on the one screen with nothing
                // beside it to compare against.
                //
                // 24 is the gap the design already puts between a band and the
                // first section label, so the page's rhythm is unchanged and
                // only the ramp's faintest tail is trimmed: the spill is down
                // to ~4% indigo by 24pt, under one L\* over the ink.
                .padding(.bottom, Theme.spacingL)
                .listRowInsets(EdgeInsets())
                .listRowBackground(Color.clear)
                .listRowSeparator(.hidden)

            ForEach(Array(monthGroups.enumerated()), id: \.element.id) { index, group in
                OCRSectionLabel(group.title)
                    // 24 above, 10 below — the same pair Settings puts around
                    // its five section labels. The 12 this used to sit on was
                    // the third value in the app for one relationship. The
                    // first group's 24 is paid by the header row above, which
                    // has to own it for the spill; a later month pays it here.
                    .padding(.top, index == 0 ? 0 : Theme.spacingL)
                    .padding(.bottom, Theme.spacingS)
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
                .ocrFont(.footnote)
                .ocrFootnoteLeading(size: 13)
                .foregroundStyle(Theme.textTertiary)
                .padding(.top, Theme.spacingS)
                .padding(.bottom, Theme.tabBarClearance)
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
    /// `ContentUnavailableView`. Its centred grey glyph, grey title and grey
    /// caption are the single most recognisable "nothing here" layout on the
    /// platform, and they would land on the ink as borrowed goods. This is the
    /// same information in the app's own vocabulary: the radar motif as the
    /// glyph, and the gradient capsule as the way out.
    private var emptyState: some View {
        ScrollView {
            VStack(spacing: 0) {
                header

                VStack(spacing: 0) {
                    // `dashedMiddle` is the empty-state variant: solid outer
                    // ring, dashed middle ring, and the ink-family centre dot,
                    // all drawn by `OCRRadar` itself.
                    OCRRadar(diameter: 66, sweeping: false, dashedMiddle: true)
                        .accessibilityHidden(true)
                        .padding(.bottom, 22)

                    Text("No scans yet")
                        .ocrFont(.sectionHead)
                        .tracking(-0.45)
                        .foregroundStyle(Theme.textPrimary)
                        .padding(.bottom, Theme.spacingS)

                    Text("Photos you compare in the Scan tab are saved here, on this device only.")
                        .ocrFont(.body)
                        .ocrBodyLeading(size: 14.5)
                        .foregroundStyle(Theme.textSecondary)
                        .multilineTextAlignment(.center)
                        .padding(.bottom, Theme.pageMargin)

                    Button {
                        selectTab(.scan)
                    } label: {
                        Label("Take your first scan", systemImage: "camera.fill")
                    }
                    // No height override: a lone call to action is 54 here, on
                    // Home's hero and in the three Scan fallbacks alike. The 50
                    // this carried was a fourth height for one role and a value
                    // the spec never names.
                    .buttonStyle(OCRPrimaryButtonStyle())
                    .frame(maxWidth: 300)
                }
                .padding(.horizontal, Theme.pageMargin)
                .padding(.top, 80)
                .padding(.bottom, Theme.tabBarClearance)
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

/// One saved comparison: a 52pt similarity avatar, the closest reference
/// category, and the shared `"<Tier> · Demo · 1h"` meta line.
///
/// The row states the category name plainly and does not repeat the sheet's
/// framing. That is a decision, not an oversight: the band above says these are
/// past comparisons and says what the avatar's number measures, the numeral
/// carries its percent sign so it is a proportion rather than a bare score, the
/// tier beside the name is next-step guidance rather than a severity, and the
/// full frame is one tap away on the detail sheet. Prefixing
/// every row with "Closest match:" would push the name itself into truncation
/// on a phone and turn a scannable list into a wall of qualifiers — which is
/// the failure mode where nobody reads the qualifier at all. VoiceOver, which
/// has no width to lose, does get the prefix; see `accessibilityText`.
///
/// The meta run is `OCRMetaLine`, not a joined string: the three tokens are the
/// same three in the same order the design pins, but the tier now carries the
/// weight, the demo marker is stated in the app's own salmon dot beside its
/// word, and the timestamp is the lightest of the three. The word "Demo" itself
/// is untouched — it is an honesty surface, so what got quieter is the
/// punctuation around it, never the label.
private struct HistoryRow: View {
    let record: ScanRecord
    /// The newest record overall wears the button gradient; older ones are flat.
    let isNewest: Bool

    /// The avatar scales with the numeral inside it — but only so far. At AX5
    /// the `.body` metric takes 52 to about 160, which is wider than the title
    /// column beside it and enough on its own to push the row past the display.
    /// Past the cap the numeral shrinks inside the circle instead.
    @ScaledMetric(relativeTo: .body) private var avatar: CGFloat = 52

    /// 1.5× the design's 52, reached at about AX1.
    private static let avatarMaxDiameter: CGFloat = 78

    /// Above this the avatar takes a line of its own — the same rule Home's
    /// earlier-scans rows follow, and for the same reason: three columns of
    /// chrome plus one line of accessibility-size text do not fit across a
    /// phone, and a row that cannot compress makes its whole container too wide.
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize

    private var diameter: CGFloat { min(avatar, Self.avatarMaxDiameter) }

    var body: some View {
        let isStacked = dynamicTypeSize.isAccessibilitySize
        let layout = isStacked
            ? AnyLayout(VStackLayout(alignment: .leading, spacing: Theme.spacingS))
            : AnyLayout(HStackLayout(spacing: Theme.spacingM))

        layout {
            HStack(spacing: 0) {
                avatarView
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
                    // Two lines is the design's allowance at reading sizes; at
                    // accessibility sizes a category name needs however many the
                    // width leaves it, and truncating the name of the *reference
                    // category* the photo resembled is not an option this screen
                    // has — a half-shown category name is a claim nobody wrote.
                    .lineLimit(isStacked ? nil : 2)
                OCRMetaLine(
                    tier: record.riskLevel.displayLabel,
                    timestamp: RelativeToken.short(for: record.timestamp),
                    isDemo: record.isDemoResult
                )
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            if !isStacked {
                OCRChevron()
            }
        }
        .padding(.vertical, Theme.spacingM)
        .padding(.horizontal, 18)
        .frame(minHeight: Theme.minTarget)
        .background(Theme.surface, in: .rect(cornerRadius: Theme.rowCorner))
        .ocrTopEdgeHighlight(RoundedRectangle(cornerRadius: Theme.rowCorner))
        .contentShape(.rect(cornerRadius: Theme.rowCorner))
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(accessibilityText)
        .accessibilityAddTraits(.isButton)
    }

    /// The similarity figure, **with its percent sign**. It read as a bare
    /// integer — "64" beside "Leukoplakia" — which is a number with no stated
    /// unit sitting next to a category name, and a reader supplies the missing
    /// unit themselves: certainty. The sign costs one glyph inside a 52pt
    /// circle and makes the numeral a proportion again, which the band above
    /// then names as similarity. `ConfidencePercent.text` is the same formatter
    /// the hero, the sheet header and the class bars use, so this cannot drift
    /// from the sheet a row opens.
    private var avatarView: some View {
        Text(percentText)
            .ocrFont(.rowTitle.size(17).weight(.semibold))
            // The confidence numeral is the app's signature, and tracking is
            // half of what makes it one: −3.6 on the hero's 76pt and −1.0 on
            // Home's 26pt rail are both ≈ −0.04em, and this avatar was the one
            // confidence figure still set at the system default. −0.7 puts it
            // on the same ratio, so a 17pt "91" in a circle reads as the same
            // typeface decision as the 76pt "91%" in the hero.
            .tracking(-0.7)
            // **Not** monospaced, and this is the one numeral in the app that
            // is not. Tabular figures reserve a full advance for the narrow
            // "1", so "91" hung 1.33pt left of its circle's centre while "64"
            // sat dead on it — visible on the newest row, which is the
            // highest-contrast chip on the screen. The design's
            // monospaced-digit rule is about columns of numbers that have to
            // line up with each other; these numerals never do, because each
            // one is centred in its own circle and only the circles align.
            .minimumScaleFactor(0.6)
            .lineLimit(1)
            .foregroundStyle(isNewest ? Theme.onGradient() : Theme.numeralMuted)
            .frame(width: diameter, height: diameter)
            .background {
                if isNewest {
                    Theme.button.clipShape(.circle)
                } else {
                    Circle().fill(Theme.surfaceRaised)
                }
            }
            .accessibilityHidden(true)
    }

    private var percentValue: Int {
        ConfidencePercent.value(record.probability)
    }

    /// "64%" — the avatar's label. Four characters at 100% still fit the
    /// circle; `minimumScaleFactor` on the label covers the rest.
    private var percentText: String {
        ConfidencePercent.text(record.probability)
    }

    /// A full sentence, so VoiceOver never reads a bare numeral. Demo records
    /// say so out loud — the visual "Demo" token would otherwise be lost.
    ///
    /// A spoken label has no column width to run out of, so this is where the
    /// row can afford the framing its visual form cannot: "closest match" ahead
    /// of the category and "percent visual similarity" instead of "percent
    /// confidence". A VoiceOver reader hears the qualifier the sighted reader
    /// gets from the band above the list, rather than a condition name followed
    /// by a number — which, read aloud with nothing around it, is the most
    /// diagnosis-shaped sentence the app could produce.
    private var accessibilityText: String {
        let when = record.timestamp.formatted(.relative(presentation: .named))
        let tier = record.riskLevel.displayLabel.lowercased()
        let base = "Comparison from \(when): closest match \(record.topClassName.lowercased()), \(percentValue) percent visual similarity, \(tier)"
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

/// Detail sheet for one saved comparison (design §6). Every value is read from
/// the tapped record — its own closest category, similarity score, tier, model
/// and timestamp — so the sheet always matches the row that opened it.
///
/// Deliberately no full ranking: a stored record keeps only its closest match,
/// and a complete similarity table belongs to a fresh comparison
/// (`ResultView`).
///
/// This and `ResultView` are the two screens in the app where a user is looking
/// at a *result*, so both are framed the same way and both carry the same one
/// piece of copy in the same place: `OCRResultDisclaimerLead` immediately under
/// the header, stating `MedicalDisclaimer.resultLead` and opening the full
/// notice. A stored scan is if anything the more consequential of the two: it is
/// read cold, weeks later, with none of the context of having just taken the
/// photo, and it is the record a person is most likely to show someone else — so
/// it is the one that can least afford a header that looks like a diagnosis. See
/// `header` for the slot mapping.
struct HistoryDetailView: View {
    let record: ScanRecord

    @Environment(\.dismiss) private var dismiss

    @State private var isShowingDisclaimer = false

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 0) {
                header

                // One gap, `spacingL`, between every sibling on the sheet — the
                // same rhythm the Result sheet and Settings now run on. This
                // used to be an 18pt stack with a 4pt top-up under the notice,
                // so the first two gaps on the page were 22 and 18.
                VStack(alignment: .leading, spacing: Theme.spacingL) {
                    resultLead

                    if record.isDemoResult {
                        demoNotice
                    }

                    detailCard

                    scanImage
                }
                .padding(.horizontal, Theme.pageMargin)
                // Matches the gap between every pair of siblings below it, so
                // the header-to-first-card step is part of the same rhythm
                // rather than a fourth value.
                .padding(.top, Theme.spacingL)
                .padding(.bottom, 44)
            }
        }
        .scrollIndicators(.hidden)
        // Sheet, so no tab bar and no status-bar overlap: only the bottom edge
        // is worth softening, and the body's 44pt bottom padding keeps the
        // last element clear of the dissolve.
        .scrollEdgeEffectStyle(.soft, for: .bottom)
        .background { OCRAmbientBackground() }
        .sheet(isPresented: $isShowingDisclaimer) {
            // A re-read, not the acknowledgement gate — so "Done", never
            // "I understand". Same component and same copy the Result sheet,
            // Home and Settings open.
            MedicalDisclaimerSheet(
                title: "Medical disclaimer",
                actionTitle: "Done",
                onAction: { isShowingDisclaimer = false }
            )
            .medicalDisclaimerPresentation()
        }
    }

    /// The same five-slot mapping `ResultView.header` uses, driven by this
    /// record instead of a fresh result — the two sheets share `OCRSheetHeader`
    /// and must not frame the same information two different ways.
    ///
    /// - **eyebrow** — "Saved comparison", so the frame is set before anything
    ///   else is read.
    /// - **meta** — when it was taken.
    /// - **hero numeral** — the similarity score.
    /// - **title** — the words "visual similarity", directly beneath the
    ///   numeral, so the two read as one phrase. This slot used to hold
    ///   `record.topClassName`, which put a condition name in the largest type
    ///   on the screen with a percentage above it: a diagnosis with a
    ///   confidence, on a record a person may open months later and show to
    ///   someone.
    /// - **tier** — the closest category, always prefixed "Closest match:", and
    ///   the next-step tier on the line below it.
    private var header: some View {
        OCRSheetHeader(
            eyebrow: "Saved comparison",
            meta: record.timestamp.formatted(.relative(presentation: .named)),
            percentText: percentText,
            title: "visual similarity",
            tierText: matchText,
            onDone: { dismiss() }
        )
    }

    private var percentText: String {
        ConfidencePercent.text(record.probability)
    }

    /// The stored closest category and the record's next-step tier, on two
    /// lines. The "Closest match:" prefix is the claim: the category name is
    /// the label on a set of reference photographs that looked alike, never a
    /// statement about what is in this person's mouth, and it never appears in
    /// this header without it.
    private var matchText: String {
        "Closest match: \(record.topClassName)\n\(record.riskLevel.displayLabel)"
    }

    /// `MedicalDisclaimer.resultLead`, verbatim, directly under the header —
    /// the same object in the same position `ResultView` puts it, for the same
    /// reason. A stored record is read with none of the context of having just
    /// taken the photo, so the frame has to arrive with the number rather than
    /// wait at the bottom of the sheet.
    ///
    /// One warning object per results surface. This sheet used to carry the
    /// lead *and* the full five-paragraph notice — the latter wedged between the
    /// detail card and the photo, which is the middle of a scroll nobody reads
    /// on purpose. The complete statement is now a tap inside this panel, which
    /// is where a reader who wants it will look for it.
    private var resultLead: some View {
        OCRResultDisclaimerLead { isShowingDisclaimer = true }
    }

    /// Clear notice that this saved scan came from the demo stand-in
    /// classifier, so an old mock record can never read as a real comparison —
    /// even in a later build that ships a trained model. This wording is the
    /// detail sheet's own; `ResultView` speaks about a result being generated
    /// right now, which would be wrong for a stored record.
    ///
    /// Like the Result sheet's, it names the mechanism rather than only calling
    /// the numbers placeholders: this is the screen where an old record is read
    /// cold, and a column of History rows all carrying the same figure is only
    /// legible as noise once a reader knows the figure came from the photo's
    /// dimensions. See `MockLesionClassifier`.
    ///
    /// It is distinct from `resultLead` above and stacks with it without
    /// merging: the lead is red and about the app on every record; this is the
    /// app's salmon demo marker and about *this* record's data.
    private var demoNotice: some View {
        OCRDemoNotice(
            title: "Demo result.",
            message: "This scan was made without a trained model. Its scores come from the photo's dimensions, not from what is in it, so every photo of the same size returns the same numbers. They carry no medical meaning."
        )
    }

    /// Four 54pt rows. `Model` reads the version stored *on the record*, not
    /// the classifier currently installed, so history stays truthful across
    /// builds.
    ///
    /// Two of the four labels changed and the values behind them did not.
    /// "Confidence" is a word about certainty in a conclusion, and the number
    /// is not that — it is how alike two images looked, so the row says "Visual
    /// similarity". "Risk tier" named a severity the app cannot assess; the
    /// value it holds is now next-step guidance ("Worth asking about"), so the
    /// row says "Next step". A guidance value under a severity label would have
    /// been the worst of both.
    private var detailCard: some View {
        VStack(spacing: 0) {
            detailRow("Visual similarity", percentText)
            rowDivider
            detailRow("Next step", record.riskLevel.displayLabel)
            rowDivider
            detailRow("Model", modelLabel)
            rowDivider
            detailRow("Scanned", scannedLabel)
        }
        .background(Theme.surface, in: .rect(cornerRadius: Theme.cardCorner))
        .ocrTopEdgeHighlight(RoundedRectangle(cornerRadius: Theme.cardCorner))
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

    /// The `monospaced` flag this used to take was never read — every value
    /// here sets tabular figures, because all four sit in one right-aligned
    /// column and are compared down it.
    private func detailRow(_ label: String, _ value: String) -> some View {
        HStack(spacing: 0) {
            Text(label)
                .ocrFont(.rowTitle.weight(.regular))
                .foregroundStyle(Theme.textSecondary)
                .layoutPriority(0)
            // The value wins the row: the label is short and fixed, so letting
            // it claim `maxWidth: .infinity` was what squeezed "Scanned" onto
            // two lines. All four rows now measure a flat 54.
            Spacer(minLength: Theme.spacingM)
            Text(value)
                .ocrFont(.rowTitle.weight(.regular))
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
                // The photo is the one element on the sheet that is not made
                // of the app's own materials, so it gets the same lit top edge
                // the cards above it have. Without it a bright frame sits on
                // the ink like a sticker; with it, it reads as another plane in
                // the same stack.
                .ocrTopEdgeHighlight(RoundedRectangle(cornerRadius: Theme.panelCorner))
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
        topClassName: "Common tissue appearance",
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
