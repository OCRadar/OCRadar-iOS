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

    /// Vertical rhythm inside the sheet body, measured from the design.
    private let afterNotice: CGFloat = 22
    private let betweenCards: CGFloat = 16
    private let beforeFootnote: CGFloat = 18

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
        .background(Theme.canvas)
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

    private func content(for top: LabelScore) -> some View {
        VStack(alignment: .leading, spacing: 0) {
            if result.isDemoResult {
                demoNotice
                    .padding(.bottom, afterNotice)
            }

            // The per-class medical summary is withheld for demo results:
            // pairing genuine medical guidance with a fabricated score would
            // lend it unearned weight.
            if !result.isDemoResult,
               let summary = classifier.manifest.classInfo(forID: top.id)?.summary {
                summaryCard(summary)
                    .padding(.bottom, betweenCards)
            }

            allClassesCard
                .padding(.bottom, betweenCards)

            professionalCallout(for: top)
                .padding(.bottom, beforeFootnote)

            disclaimerFootnote
        }
        .modifier(SheetBodyInsets())
    }

    /// A result with no scores still has to render something sane and
    /// dismissible — the header's Done button remains the way out.
    private var emptyScoresContent: some View {
        VStack(alignment: .leading, spacing: 0) {
            if result.isDemoResult {
                demoNotice
                    .padding(.bottom, afterNotice)
            }

            OCRCard(corner: Theme.panelCorner, padding: 20) {
                Text("The analysis returned no scores. Try another photo.")
                    .font(.ocrBody())
                    .foregroundStyle(Theme.textSecondary)
                    .lineSpacing(3)
                    .fixedSize(horizontal: false, vertical: true)
                    .padding(.vertical, 2)
            }
            .padding(.bottom, betweenCards)

            // With no top score there is no tier, so only the generic
            // when-in-doubt guidance can apply.
            genericCallout
                .padding(.bottom, beforeFootnote)

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
        OCRCard(corner: Theme.panelCorner, padding: 20) {
            Text(summary)
                .font(.ocrBody())
                .foregroundStyle(Theme.textSecondary)
                .lineSpacing(3)
                .fixedSize(horizontal: false, vertical: true)
                .padding(.vertical, 2)
        }
    }

    // MARK: - All classes

    private var allClassesCard: some View {
        OCRCard(corner: Theme.panelCorner, padding: 20) {
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
            .padding(.vertical, 2)
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
        OCRCard(corner: Theme.panelCorner, padding: 20) {
            VStack(alignment: .leading, spacing: 9) {
                HStack(alignment: .firstTextBaseline, spacing: 12) {
                    Image(systemName: "stethoscope")
                        .font(.system(size: 21))
                        .foregroundStyle(Theme.accent)
                        .accessibilityHidden(true)
                    Text(title)
                        .font(.system(size: 16.5, weight: .semibold))
                        .tracking(-0.25)
                        .fixedSize(horizontal: false, vertical: true)
                }
                Text(detail)
                    .font(.system(size: 14))
                    .foregroundStyle(Theme.textSecondary)
                    .lineSpacing(3)
                    .fixedSize(horizontal: false, vertical: true)
            }
            .padding(.vertical, 2)
        }
        .accessibilityElement(children: .combine)
    }

    // MARK: - Footnote

    private var disclaimerFootnote: some View {
        Text(MedicalDisclaimer.full)
            .font(.ocrFootnote())
            .foregroundStyle(Theme.textTertiary)
            .lineSpacing(4)
            .fixedSize(horizontal: false, vertical: true)
    }
}

/// Shared page insets for the sheet body below the gradient header.
private struct SheetBodyInsets: ViewModifier {
    func body(content: Content) -> some View {
        content
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.horizontal, Theme.pageMargin)
            .padding(.top, Theme.pageMargin)
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
