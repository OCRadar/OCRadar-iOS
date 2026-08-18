import OCRCore
import SwiftUI

/// Presents one comparison outcome: a gradient sheet header carrying the visual
/// similarity score and the closest-matching reference category, the medical
/// lead, the similarity ranking across every category, and the next-step
/// guidance.
///
/// # This sheet is a comparison, not a finding
///
/// OCRadar is an awareness tool. It does not screen, detect, diagnose, assess or
/// rule anything in or out — it reports *visual similarity* to reference
/// categories, and it never states what a lesion is. This screen is where that
/// position is either kept or lost, because it is the one surface a reader
/// treats as the app's answer.
///
/// The header used to read `76pt "32%"` → `"Leukoplakia"` → `"Moderate risk"`:
/// a named condition, a confidence, and a severity, stacked in descending size.
/// That is the shape of a diagnosis, and no amount of fine print underneath
/// changes how it is read. The header now reads `"32%"` → `"visual
/// similarity"` → `"Closest match: Leukoplakia"` → the next-step tier, so the
/// largest thing on the sheet is a *measurement of likeness* the app can
/// honestly claim, and the category name is a supporting detail beneath it
/// rather than the headline. See `header` for the slot-by-slot reasoning.
///
/// `MedicalDisclaimer.resultLead` then sits immediately under the header — the
/// moment of highest consequence, and the point at which a reader is least
/// likely to scroll for context. It is the sheet's *one* warning object
/// (`OCRResultDisclaimerLead`), and the full statement is one tap inside it.
/// This sheet used to carry the lead **and** all five paragraphs of
/// `MedicalDisclaimer.full` in a second red panel at its foot; two bordered red
/// panels around one result do not double the warning, they halve it.
///
/// The compared photo is deliberately **not** shown here. The sheet's contents
/// are exactly — header, lead, demo banner, similarity ranking,
/// callout — and an earlier draft's 200pt image card between
/// the banner and the scores dominated the sheet and pushed the scores below
/// the fold. The view therefore does not take an image at all; the saved photo
/// remains visible in `HistoryDetailView`.
///
/// Three honesty rules are load-bearing here and must not be simplified:
/// the demo notice and the " · demo result" meta suffix appear for every demo
/// result; the professional-care callout has two mutually exclusive branches
/// and a demo score never receives the tier copy; per-class summaries are
/// withheld for demo results.
///
/// A fourth now sits beside them: this sheet is one of the two places in the
/// app where a user is looking at a *result*, so the medical disclaimer is not
/// a footnote here. It is bordered, red in a way nothing else on the page is,
/// and it is the first thing under the number rather than the last thing under
/// the scroll. See `resultLead`.
struct ResultView: View {
    let result: ClassificationResult

    @Environment(\.lesionClassifier) private var classifier
    @Environment(\.dismiss) private var dismiss

    @State private var isShowingDisclaimer = false

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 0) {
                header

                // Order matters: the abstaining case is checked before the
                // normal one, because `result.top` is non-nil in both. A
                // rejected comparison still has a highest score — that is
                // exactly what makes it dangerous to render with the ordinary
                // branch.
                if result.isBelowAbstainThreshold {
                    noConfidentMatchContent
                } else if let top = result.confidentTop {
                    content(for: top)
                } else {
                    emptyScoresContent
                }
            }
        }
        .scrollIndicators(.hidden)
        .ocrQAScrollBottom()
        // Sheet, so no tab bar and no status-bar overlap: only the bottom edge
        // is worth softening. `SheetBodyInsets` pads 44 below the medical
        // notice, which keeps its border clear of the dissolve — a soft edge
        // eating the bottom of the one panel that must read as a closed
        // rectangle would undo the shape the notice is recognised by.
        .scrollEdgeEffectStyle(.soft, for: .bottom)
        .background { OCRAmbientBackground() }
        .foregroundStyle(Theme.textPrimary)
        .presentationBackground(Theme.canvas)
        .presentationCornerRadius(Theme.sheetCorner)
        .sheet(isPresented: $isShowingDisclaimer) {
            // A re-read, not the acknowledgement gate — so "Done", never
            // "I understand". Same component, same copy, same presentation
            // Home and Settings open.
            MedicalDisclaimerSheet(
                title: "Medical disclaimer",
                actionTitle: "Done",
                onAction: { isShowingDisclaimer = false }
            )
            .medicalDisclaimerPresentation()
        }
    }

    // MARK: - Header

    /// `OCRSheetHeader` draws its five slots top to bottom — eyebrow, meta,
    /// hero numeral, title, tier — and this screen no longer maps them onto
    /// "class name, confidence, risk". The component is shared with
    /// `HistoryDetailView` and is not this file's to restructure, so the
    /// reframing is done by choosing what goes in each slot:
    ///
    /// - **eyebrow** — "Visual comparison". The first words on the sheet name
    ///   what the sheet is, before any number or category appears.
    /// - **meta** — recency, carrying the demo suffix (honesty rule 1).
    /// - **hero numeral** — the score. Kept at 76pt, because a similarity score
    ///   *is* the measured result and hiding it would be its own kind of
    ///   dishonesty — but it is no longer allowed to stand unlabelled.
    /// - **title** — `heroLabel`, the words "visual similarity", set in
    ///   `screenTitle` directly beneath the numeral so the two read as one
    ///   phrase: **"32% visual similarity"**. This slot used to hold the
    ///   category name, which is exactly why the old header read as a
    ///   diagnosis: the largest words on the screen asserted what the lesion
    ///   *was*. The largest words now assert only how alike two images looked,
    ///   which is the only claim the app can support.
    /// - **tier** — `matchText`: the closest-matching category, explicitly
    ///   prefixed "Closest match:", then the next-step tier on its own line.
    ///   When the comparison fell below the model's confidence floor, this slot
    ///   carries `MedicalDisclaimer.noConfidentMatchNextStep` instead and no
    ///   category name appears in the header at all.
    ///   The category name is therefore always *below* and *smaller than* the
    ///   comparison framing, and never appears without it.
    private var header: some View {
        OCRSheetHeader(
            eyebrow: "Visual comparison",
            meta: metaText,
            percentText: heroPercentText,
            title: heroLabel,
            tierText: matchText,
            onDone: { dismiss() }
        )
    }

    /// "Compared just now", with the demo suffix appended for demo results only.
    ///
    /// The suffix is honesty rule 1 and is unconditional for a demo result. The
    /// stem changed from "Just analyzed" because "analyzed" is the vocabulary of
    /// an assessment; this sheet compares.
    private var metaText: String {
        result.isDemoResult ? "Compared just now · demo result" : "Compared just now"
    }

    /// Shares `ConfidencePercent` with Home, History and the class bars: the
    /// scan saved by this very sheet must not read a point apart in the History
    /// row it creates.
    private var heroPercentText: String {
        // An abstaining result takes the em dash, the same as one with no
        // scores at all. The closest score is still knowable — it is in the
        // similarity ranking further down the sheet — but it must not be the
        // 76pt headline. A percentage in that slot beside "no confident match"
        // is read as the strength of a finding, and there is no finding; it is
        // the number the app has just declined to act on.
        guard !result.isBelowAbstainThreshold, let top = result.top else { return "—" }
        return ConfidencePercent.text(top.probability)
    }

    /// The label the hero numeral is read with, never without.
    ///
    /// Lowercase, because it is the second half of a phrase the numeral starts
    /// rather than a title of its own — "32%" / "visual similarity". A bare
    /// percentage beside a condition name reads as diagnostic certainty; the
    /// same percentage under these two words reads as what it is, which is how
    /// closely one photograph resembled a set of reference photographs.
    private var heroLabel: String {
        if result.isBelowAbstainThreshold { return MedicalDisclaimer.noConfidentMatchTitle }
        return result.top == nil ? "no comparison available" : "visual similarity"
    }

    /// The closest reference category and the next step, on two lines.
    ///
    /// "Closest match:" is not decoration — it is the whole claim. Without it
    /// the category name is an assertion about the reader's mouth; with it the
    /// name is the label on a reference image that looked alike. The category
    /// never appears in this header unprefixed.
    ///
    /// The second line is `RiskLevel.displayLabel`, which is next-step guidance
    /// ("Worth asking about"), not a severity. Nothing here says "risk", and
    /// nothing here may be made to.
    private var matchText: String {
        // No category cleared the floor, so no category is named here — not
        // even prefixed. "Closest match: Leukoplakia" under the words "no
        // confident match" would hand back with the second line precisely what
        // the first line withheld.
        if result.isBelowAbstainThreshold { return MedicalDisclaimer.noConfidentMatchNextStep }
        guard let top = result.confidentTop else { return "No scores returned" }
        return "Closest match: \(top.displayName)\n\(top.riskLevel.displayLabel)"
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
            resultLead

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

            // The guidance closes the sheet. The frame — "a visual comparison,
            // not a diagnosis" — has already been stated at the top, beside the
            // number, which is where it is actually read; repeating it here in a
            // second red panel is what taught readers to skip the first one.
            professionalCallout(for: top)
        }
        .modifier(SheetBodyInsets())
    }

    /// The sheet when the comparison did not clear the model's confidence
    /// floor.
    ///
    /// It keeps the same objects in the same order as a normal result — lead,
    /// demo notice, an explanatory card where the per-class summary would be,
    /// the similarity ranking, the closing guidance — because a state that
    /// rearranges the page announces itself as an error, and this is not an
    /// error. It is an ordinary outcome of comparing a photograph with a small
    /// set of reference photographs.
    ///
    /// The similarity ranking stays. Withholding the numbers as well as the
    /// name would leave a reader unable to see whether the call was close or
    /// nowhere near, and the card's own subtitle already frames the bars as
    /// resemblance rather than verdicts. What the sheet withholds is the
    /// *claim*: no category is named as the match anywhere above this card.
    ///
    /// The per-class summary is withheld for the same reason it is withheld
    /// for a demo result — it is medical guidance attached to a category, and
    /// no category has been established.
    private var noConfidentMatchContent: some View {
        VStack(alignment: .leading, spacing: Theme.spacingL) {
            resultLead

            if result.isDemoResult {
                demoNotice
            }

            OCRCard(corner: Theme.panelCorner) {
                Text(MedicalDisclaimer.noConfidentMatch)
                    .ocrFont(.body)
                    .foregroundStyle(Theme.textSecondary)
                    .ocrBodyLeading(size: 14.5)
                    .fixedSize(horizontal: false, vertical: true)
            }

            allClassesCard

            // No category means no tier, so the only guidance that can apply is
            // the one that never depended on the comparison succeeding.
            genericCallout
        }
        .modifier(SheetBodyInsets())
    }

    /// A result with no scores still has to render something sane and
    /// dismissible — the header's Done button remains the way out.
    private var emptyScoresContent: some View {
        VStack(alignment: .leading, spacing: Theme.spacingL) {
            resultLead

            if result.isDemoResult {
                demoNotice
            }

            OCRCard(corner: Theme.panelCorner) {
                Text("The comparison returned no scores. Try another photo.")
                    .ocrFont(.body)
                    .foregroundStyle(Theme.textSecondary)
                    .ocrBodyLeading(size: 14.5)
                    .fixedSize(horizontal: false, vertical: true)
            }

            // With no top score there is no tier, so only the generic
            // when-in-doubt guidance can apply.
            genericCallout
        }
        .modifier(SheetBodyInsets())
    }

    /// The sheet's one warning object: `MedicalDisclaimer.resultLead` verbatim,
    /// in the app's red frame, with "Read the full notice" inside it.
    ///
    /// # Why here rather than at the foot
    ///
    /// The foot of a scroll view is not where a person decides what a result
    /// means — they decide in the second they read the number. This sentence is
    /// the one that has to arrive in that second, so it sits directly under the
    /// header, in the reader's path rather than at the end of it. It costs no
    /// tap and blocks nothing: prominence without friction.
    ///
    /// # Why it is the only one
    ///
    /// `OCRResultDisclaimerLead` carries the whole argument for that; the short
    /// version is that this sheet previously stated the disclaimer twice — here
    /// and again as five paragraphs at the foot — and a reader who has learned
    /// to skip the first red panel skips the second. One per results surface.
    ///
    /// The string is a `MedicalDisclaimer` constant passed whole by the
    /// component. It is not paraphrased, shortened or line-limited.
    private var resultLead: some View {
        OCRResultDisclaimerLead { isShowingDisclaimer = true }
    }

    /// Shown whenever the result came from the demo stand-in classifier, so a
    /// mock score can never be mistaken for a real comparison — regardless of
    /// how the user reached this screen.
    ///
    /// The message names the mechanism now, and that is the whole point of it.
    /// "Generated placeholders" is true but weightless beside a 76pt
    /// percentage; what makes the number legible as nothing is knowing that it
    /// came from the photo's *dimensions*, so a second photo of the same lesion
    /// — or of a doorframe — returns the identical figure. Without that
    /// sentence the repetition down a History list reads as consistency, which
    /// is the most convincing thing a fabricated score could possibly do. See
    /// `MockLesionClassifier`, which must not change without this copy changing
    /// with it.
    private var demoNotice: some View {
        OCRDemoNotice(
            title: "Demo result — no trained model installed.",
            message: "This score comes from the photo's dimensions, not from what is in it, so every photo of the same size returns the same numbers. It carries no medical meaning."
        )
    }

    private func summaryCard(_ summary: String) -> some View {
        OCRCard(corner: Theme.panelCorner) {
            Text(summary)
                .ocrFont(.body)
                .foregroundStyle(Theme.textSecondary)
                .ocrBodyLeading(size: 14.5)
                .fixedSize(horizontal: false, vertical: true)
        }
    }

    // MARK: - Similarity ranking

    /// `OCRCard`'s own 18pt inset, on all four sides, like every other card in
    /// the app. The four cards on this sheet used to pass `padding: 20`, which
    /// put their first pixel of content 2pt right of the demo notice stacked
    /// 22pt above them — the two cards' contents were on different rails inside
    /// one column.
    ///
    /// The card was titled "All classes", which says nothing about what the
    /// numbers beside those names mean — and a column of condition names each
    /// carrying a percentage, under a title that does not qualify them, is a
    /// differential diagnosis. It is not one: it is one photograph measured
    /// against five sets of reference photographs and sorted by likeness. The
    /// title and the line under it say so, so the bars are read as a ranking of
    /// resemblance rather than a set of competing verdicts.
    private var allClassesCard: some View {
        OCRCard(corner: Theme.panelCorner) {
            VStack(alignment: .leading, spacing: 0) {
                Text("Similarity ranking")
                    .ocrFont(.cardTitle)
                    .tracking(-0.25)
                    .fixedSize(horizontal: false, vertical: true)
                    .padding(.bottom, 6)

                Text("How closely this photo resembled each reference category.")
                    .ocrFont(.body.size(14))
                    .foregroundStyle(Theme.textSecondary)
                    .ocrBodyLeading(size: 14)
                    .fixedSize(horizontal: false, vertical: true)
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

    /// Two mutually exclusive branches, unchanged in structure and unchanged in
    /// what they guarantee: a demo score can never receive the tier copy, and
    /// the two strings are never blended.
    ///
    /// What changed is the copy the tier branch carries. It used to read "This
    /// result falls in a tier that warrants professional evaluation" — a
    /// severity claim about the reader, dressed as a routing instruction, and
    /// no longer true of a tier that means "what to do next" rather than "how
    /// bad this is". `RiskLevel.guidanceDetail` is the canonical sentence for
    /// exactly this slot, written once and inherited here, so the guidance is
    /// never hand-written at a call site and never drifts from the label in the
    /// header above it.
    @ViewBuilder
    private func professionalCallout(for top: LabelScore) -> some View {
        if top.riskLevel >= .moderate, !result.isDemoResult {
            calloutCard(
                title: "What to do next",
                detail: top.riskLevel.guidanceDetail
            )
        } else {
            genericCallout
        }
    }

    /// The branch a demo result, a low tier and a scoreless result all land on.
    ///
    /// It used to say a professional exam is what can "rule a lesion in or
    /// out". Ruling in and out is the vocabulary of screening, and this app
    /// does neither — so the sentence now says the plain thing instead: the app
    /// cannot tell you what something is, and a person can.
    private var genericCallout: some View {
        calloutCard(
            title: "When in doubt, see a dentist or physician",
            detail: "This app cannot tell you what something is. If anything in your mouth concerns you, have it looked at."
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
                        .ocrFont(.cardTitle)
                        .tracking(-0.25)
                        .fixedSize(horizontal: false, vertical: true)
                }
                Text(detail)
                    .ocrFont(.body.size(14))
                    .foregroundStyle(Theme.textSecondary)
                    .ocrBodyLeading(size: 14)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
        .accessibilityElement(children: .combine)
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

#Preview("No confident match") {
    let classes = ModelManifest.mockOralLesions.classes
    // Nothing resembles anything much: the top score is 0.31 against a floor
    // of 0.45, which is the shape of a photo the reference set does not cover.
    let probabilities: [Double] = [0.31, 0.22, 0.19, 0.16, 0.12]
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
        modelVersion: "1.0.0",
        inferenceDuration: .milliseconds(180),
        abstainThreshold: 0.45
    )
    ResultView(result: result)
        .environment(\.lesionClassifier, MockLesionClassifier())
        .preferredColorScheme(.dark)
}
