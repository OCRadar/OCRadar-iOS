import OCRCore
import SwiftUI

/// Presents one classification outcome: a gradient sheet header carrying the
/// top class and its confidence, every class score, and the professional-care
/// guidance plus the full medical disclaimer.
///
/// The analyzed photo is deliberately **not** shown here. The design lists the
/// sheet's contents exactly — header, demo banner, all-classes card, callout,
/// medical notice — and an earlier draft's 200pt image card between the banner
/// and the scores dominated the sheet and pushed the scores below the fold. The
/// view therefore does not take an image at all; the saved photo remains
/// visible in `HistoryDetailView`.
///
/// Three honesty rules are load-bearing here and must not be simplified:
/// the demo notice and the " · demo result" meta suffix appear for every demo
/// result; the professional-care callout has two mutually exclusive branches
/// and a demo score never receives the tier copy; per-class summaries are
/// withheld for demo results.
///
/// A fourth now sits beside them: this sheet is one of the two places in the
/// app where a user is looking at a *result*, so the medical disclaimer is not
/// a footnote here. It is `OCRMedicalNotice` — bordered, titled,
/// and red in a way nothing else on the page is — and it closes the sheet
/// directly beneath the professional-care callout. See `medicalNotice` for why
/// that position, and why the red cannot be confused with a risk tier.
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
        // is worth softening. `SheetBodyInsets` pads 44 below the medical
        // notice, which keeps its border clear of the dissolve — a soft edge
        // eating the bottom of the one panel that must read as a closed
        // rectangle would undo the shape the notice is recognised by.
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

            // Guidance, then the notice — never the other way round. "See a
            // dentist" followed by "this is not a diagnosis" reads as one
            // thought finishing itself; reversed, the notice would read as a
            // preamble the callout then contradicts.
            professionalCallout(for: top)

            medicalNotice
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
                    .ocrFont(.body)
                    .foregroundStyle(Theme.textSecondary)
                    .ocrBodyLeading(size: 14.5)
                    .fixedSize(horizontal: false, vertical: true)
            }

            // With no top score there is no tier, so only the generic
            // when-in-doubt guidance can apply.
            genericCallout

            medicalNotice
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
                .ocrFont(.body)
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
                    .ocrFont(.cardTitle)
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

    // MARK: - Medical notice

    /// The disclaimer, as the object it has to be on a result screen.
    ///
    /// This was 13pt `Theme.textTertiary` copy — the lightest ink in the app,
    /// set at the smallest size in the app, on the screen a user reaches by
    /// pointing a camera at their own mouth. It was the least visible thing on
    /// the most consequential page. `OCRMedicalNotice` is the fix: a bordered,
    /// titled panel with a warning glyph, drawn identically on every screen
    /// that carries it.
    ///
    /// **No quieter variant, here least of all.** `OCRMedicalNotice` has one
    /// form and takes no prominence argument, which matters most on this
    /// screen: a result sheet is the moment a person decides whether to worry,
    /// and the notice is the last thing standing between them and acting on a
    /// number a phone produced. The disclaimer is set in `Theme.textPrimary` so
    /// it is actually read rather than merely present.
    ///
    /// **Why it sits here, at the foot.** The reading order is result →
    /// guidance → "and this is not a diagnosis", and each step depends on the
    /// one before it. Hoisting the notice above `allClassesCard` would place it
    /// in the middle of the result the user opened the sheet for, and a warning
    /// that interrupts the thing it is warning about gets read as an obstacle
    /// and dismissed. Directly beneath `professionalCallout` it instead closes
    /// the argument the callout starts. It reaches the reader on the strength
    /// of the frame, not the scroll position — which is the whole point of
    /// giving it one.
    ///
    /// **Why the red does not collide with the high-risk tier.** It cannot: the
    /// tiers carry no colour at all (`RiskLevel.displayLabel` renders "Low
    /// risk" / "Moderate risk" / "High risk" as plain ambient text, in the
    /// header above and in every History row). And even if a tier palette
    /// returned, the separation here is by *form* — this is the only outlined,
    /// titled, glyph-led rectangle in the app, and a tier is a run of words
    /// inside a sentence. Nothing about a low-risk result changes what this
    /// panel looks like, because it is drawn the same for every result.
    ///
    /// The string is `MedicalDisclaimer.full`, verbatim and unabridged, exactly
    /// as the footnote it replaces set it.
    private var medicalNotice: some View {
        OCRMedicalNotice(MedicalDisclaimer.full)
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
