import OCRCore
import SwiftUI

/// Presents one classification outcome: a gradient sheet header carrying the
/// top class and its confidence, every class score, and the professional-care
/// guidance plus the full medical disclaimer.
///
/// The analyzed photo is deliberately **not** shown here. The design lists the
/// sheet's contents exactly — header, demo banner, all-classes card, callout,
/// footnote — and an earlier draft's 200pt image card between the banner and
/// the scores dominated the sheet and pushed the scores below the fold. The
/// view therefore does not take an image at all; the saved photo remains
/// visible in `HistoryDetailView`.
///
/// Three honesty rules are load-bearing here and must not be simplified:
/// the demo notice and the " · demo result" meta suffix appear for every demo
/// result; the professional-care callout has two mutually exclusive branches
/// and a demo score never receives the tier copy; per-class summaries are
/// withheld for demo results.
struct ResultView: View {
    let result: ClassificationResult

    @Environment(\.lesionClassifier) private var classifier
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 0) {
                header

                if let top = result.top {
                    content(for: top)
                } else {
                    emptyScoresContent
                }
            }
        }
        .scrollIndicators(.hidden)
        .ocrQAScrollBottom()
        // Sheet, so no tab bar and no status-bar overlap: only the bottom edge
        // is worth softening. `SheetBodyInsets` pads 44 below the disclaimer,
        // which keeps the last line clear of the dissolve.
        .scrollEdgeEffectStyle(.soft, for: .bottom)
        .background { OCRAmbientBackground() }
        .foregroundStyle(Theme.textPrimary)
        .presentationBackground(Theme.canvas)
        .presentationCornerRadius(Theme.sheetCorner)
    }

    // MARK: - Header

    private var header: some View {
        OCRSheetHeader(
            eyebrow: "Result",
            meta: metaText,
            percentText: heroPercentText,
            title: result.top?.displayName ?? "No result",
            tierText: result.top?.riskLevel.displayLabel ?? "No scores returned",
            onDone: { dismiss() }
        )
    }

    /// "Just analyzed", with the demo suffix appended for demo results only.
    private var metaText: String {
        result.isDemoResult ? "Just analyzed · demo result" : "Just analyzed"
    }

    /// Shares `ConfidencePercent` with Home, History and the class bars: the
    /// scan saved by this very sheet must not read a point apart in the History
    /// row it creates.
    private var heroPercentText: String {
        guard let top = result.top else { return "—" }
        return ConfidencePercent.text(top.probability)
    }

    // MARK: - Body

    /// One gap, `Theme.spacingL`, between every sibling on the sheet.
    ///
    /// This body used to declare three private constants (22 / 16 / 18) on top
    /// of a 26pt top pad, so the gaps shrank monotonically down the page — 26,
    /// 22, 16 — for no reason a reader could name. Settings runs a single
    /// `spacingL` between every one of its groups and measures dead even, which
    /// is the rhythm this now shares.
    private func content(for top: LabelScore) -> some View {
        VStack(alignment: .leading, spacing: Theme.spacingL) {
            if result.isDemoResult {
                demoNotice
            }

            // The per-class medical summary is withheld for demo results:
            // pairing genuine medical guidance with a fabricated score would
            // lend it unearned weight.
            if !result.isDemoResult,
               let summary = classifier.manifest.classInfo(forID: top.id)?.summary {
                summaryCard(summary)
            }

            allClassesCard

            professionalCallout(for: top)

            disclaimerFootnote
        }
        .modifier(SheetBodyInsets())
    }

    /// A result with no scores still has to render something sane and
    /// dismissible — the header's Done button remains the way out.
    private var emptyScoresContent: some View {
        VStack(alignment: .leading, spacing: Theme.spacingL) {
            if result.isDemoResult {
                demoNotice
            }

            OCRCard(corner: Theme.panelCorner) {
                Text("The analysis returned no scores. Try another photo.")
                    .font(.ocrBody())
                    .foregroundStyle(Theme.textSecondary)
                    .ocrBodyLeading(size: 14.5)
                    .fixedSize(horizontal: false, vertical: true)
            }

            // With no top score there is no tier, so only the generic
            // when-in-doubt guidance can apply.
            genericCallout

            disclaimerFootnote
        }
        .modifier(SheetBodyInsets())
    }

    /// Shown whenever the result came from the demo stand-in classifier, so a
    /// mock score can never be mistaken for real analysis — regardless of how
    /// the user reached this screen.
    private var demoNotice: some View {
        OCRDemoNotice(
            title: "Demo result — no trained model installed.",
            message: "These scores are generated placeholders and carry no medical meaning."
        )
    }

    private func summaryCard(_ summary: String) -> some View {
        OCRCard(corner: Theme.panelCorner) {
            Text(summary)
                .font(.ocrBody())
                .foregroundStyle(Theme.textSecondary)
                .ocrBodyLeading(size: 14.5)
                .fixedSize(horizontal: false, vertical: true)
        }
    }

    // MARK: - All classes

    /// `OCRCard`'s own 18pt inset, on all four sides, like every other card in
    /// the app. The four cards on this sheet used to pass `padding: 20`, which
    /// put their first pixel of content 2pt right of the demo notice stacked
    /// 22pt above them — the two cards' contents were on different rails inside
    /// one column.
    private var allClassesCard: some View {
        OCRCard(corner: Theme.panelCorner) {
            VStack(alignment: .leading, spacing: 0) {
                Text("All classes")
                    .font(.ocrCardTitle())
                    .tracking(-0.25)
                    .padding(.bottom, 20)

                // `result.scores` is already sorted most-probable first, so the
                // index is the rank: 0 takes the top bar, the rest step down
                // the purple ramp.
                VStack(alignment: .leading, spacing: Theme.spacingM) {
                    ForEach(Array(result.scores.enumerated()), id: \.element.id) { index, score in
                        OCRClassBar(
                            name: score.displayName,
                            probability: score.probability,
                            rank: index
                        )
                    }
                }
            }
        }
    }

    // MARK: - Professional care

    /// Two mutually exclusive branches. A demo score cannot "fall in a tier
    /// that warrants professional evaluation" — only the generic when-in-doubt
    /// guidance applies to it. The two strings are never blended.
    @ViewBuilder
    private func professionalCallout(for top: LabelScore) -> some View {
        if top.riskLevel >= .moderate, !result.isDemoResult {
            calloutCard(
                title: "See a dentist or physician",
                detail: "This result falls in a tier that warrants professional evaluation. Book an appointment soon rather than waiting."
            )
        } else {
            genericCallout
        }
    }

    private var genericCallout: some View {
        calloutCard(
            title: "When in doubt, see a dentist or physician",
            detail: "Only a professional exam can rule a lesion in or out."
        )
    }

    private func calloutCard(title: String, detail: String) -> some View {
        OCRCard(corner: Theme.panelCorner) {
            // `iconGap`-wide, icon-rail layout — the same shape the Settings
            // rows and the Privacy card use. The stethoscope was the one accent
            // glyph in the app at 21pt while every other sat at 19, so the one
            // icon a user meets on the result of a scan was the odd one out.
            VStack(alignment: .leading, spacing: 9) {
                // 14, the gap Settings puts between the same glyph box and the
                // same kind of title. At 12 it was the app's second
                // icon-to-title distance.
                HStack(alignment: .firstTextBaseline, spacing: 14) {
                    OCRRowIcon(systemName: "stethoscope", titleSize: 16.5)
                    Text(title)
                        .font(.ocrCardTitle())
                        .tracking(-0.25)
                        .fixedSize(horizontal: false, vertical: true)
                }
                Text(detail)
                    .font(.system(size: 14))
                    .foregroundStyle(Theme.textSecondary)
                    .ocrBodyLeading(size: 14)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
        .accessibilityElement(children: .combine)
    }

    // MARK: - Footnote

    private var disclaimerFootnote: some View {
        Text(MedicalDisclaimer.full)
            .font(.ocrFootnote())
            .foregroundStyle(Theme.textTertiary)
            .ocrFootnoteLeading(size: 13)
            .fixedSize(horizontal: false, vertical: true)
    }
}

/// Shared page insets for the sheet body below the gradient header.
private struct SheetBodyInsets: ViewModifier {
    func body(content: Content) -> some View {
        content
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.horizontal, Theme.pageMargin)
            // `spacingL`, so the header-to-first-card step is the same gap as
            // every step between the cards below it.
            .padding(.top, Theme.spacingL)
            .padding(.bottom, 44)
    }
}

#Preview {
    let classes = ModelManifest.mockOralLesions.classes
    let probabilities: [Double] = [0.07, 0.06, 0.12, 0.52, 0.23]
    let scores = zip(classes, probabilities).map { info, probability in
        LabelScore(
            id: info.id,
            displayName: info.displayName,
            riskLevel: info.riskLevel,
            probability: probability
        )
    }
    let result = ClassificationResult(
        scores: scores,
        modelVersion: "mock-0.0.0",
        inferenceDuration: .milliseconds(180)
    )
    ResultView(result: result)
        .environment(\.lesionClassifier, MockLesionClassifier())
        .preferredColorScheme(.dark)
}
