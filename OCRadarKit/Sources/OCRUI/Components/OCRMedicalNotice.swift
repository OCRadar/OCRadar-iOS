import OCRCore
import SwiftUI

/// The medical notice, as an object rather than a footnote.
///
/// Every disclaimer in the app used to be set as 13pt `Theme.textTertiary` copy
/// at the bottom of a scroll view — technically present, and the single easiest
/// thing on the screen to skip. This is the replacement, and it is the *only*
/// way the notice is drawn: one component, one title, one visual language, in
/// the same place on every screen that carries it.
///
/// # One form, deliberately
///
/// There is no quiet variant and no prominence switch. Every screen that
/// carries the notice — Home, Settings, the Result sheet, the scan-detail
/// sheet — draws this exact object at this exact weight, because the thing the
/// notice says does not get less true on a screen that already looks busy. A
/// dial for "how loudly does this app admit it is not a diagnosis" is a dial
/// that only ever gets turned down, so it does not exist. Callers choose the
/// *string* (`MedicalDisclaimer.short` or `.full`) and nothing else.
///
/// # Why it is red, and why that does not collide with a tier
///
/// Red beside a health-adjacent result is a loaded colour: the obvious reading
/// of a red panel wrapped around a result is "this result is bad". That reading
/// has to be impossible here, because the notice says the opposite — it says the
/// app is not competent to tell you whether the result is bad.
///
/// The separation is by **form**, not by hue. A tier is inline text inside
/// a sentence ("Worth asking about · 2h ago") in the ambient ink colours — see
/// `RiskLevel.displayLabel`, and note that the restyle deliberately left tiers
/// with no colour of their own. The notice is a bordered rectangle with a
/// warning glyph and a fixed title, and it is the only object in the app shaped
/// that way. Nothing else has a coloured outline; nothing else opens with a
/// triangle. A reader does not have to resolve a hue to tell the two apart, and
/// neither does a reader who cannot resolve hues at all.
///
/// The constraint that keeps this true is stated at `Theme.medicalNoticeInk`: if
/// a tier palette is ever reintroduced, it must colour *text* only.
///
/// # Why the body copy is not red
///
/// Only the frame is red — border, glyph, title. The disclaimer itself is set in
/// `Theme.textPrimary`, which measures 18.01:1 on `Theme.medicalNoticeFill`.
/// Four lines of saturated red on a dark canvas is hard reading, and a notice
/// nobody finishes is a notice that failed at the one thing it is for. Red marks
/// the object; near-white carries the sentence.
///
/// # The copy is never this file's business
///
/// `title` is fixed app-wide. The body is whatever the caller passes, verbatim —
/// in practice `MedicalDisclaimer.short` or `MedicalDisclaimer.full`, which are
/// the canonical strings and the only ones permitted here. This view must never
/// paraphrase, truncate, or line-limit what it is given; there is no
/// `lineLimit` anywhere below, and there must not be one.
struct OCRMedicalNotice: View {
    /// Fixed app-wide, and deliberately a plain-language claim rather than a
    /// label like "Disclaimer" or "Important". It states the thing the reader
    /// has to leave with, so a reader who reads the title and nothing else has
    /// still received the notice.
    static let title = "Not a medical diagnosis"

    private let text: String

    /// - Parameter text: The disclaimer, verbatim. Pass
    ///   `MedicalDisclaimer.short` or `MedicalDisclaimer.full` — never a
    ///   rewrite of either.
    init(_ text: String) {
        self.text = text
    }

    var body: some View {
        // `.firstTextBaseline`, not `.top` and not `.center`: the glyph belongs
        // to the title, so it is anchored to the title's cap band and stays
        // there when the body copy wraps to five lines at an accessibility text
        // size. Centred on the whole block it would drift downward as the notice
        // grew; `.top` would leave it floating above the title's cap height.
        HStack(alignment: .firstTextBaseline, spacing: Metrics.gap) {
            Image(systemName: "exclamationmark.triangle.fill")
                .font(.system(size: iconSize, weight: .semibold))
                .foregroundStyle(Theme.medicalNoticeInk)
                .ocrCapCentred(on: Metrics.titleStyle.size)
                // Decorative: the title says "Not a medical diagnosis" in
                // words, so a VoiceOver reader gains nothing from "warning,
                // triangle" ahead of it. Hidden children are dropped by the
                // `.combine` below, which is how the element ends up reading as
                // one sentence instead of three fragments.
                .accessibilityHidden(true)
            VStack(alignment: .leading, spacing: Metrics.titleGap) {
                Text(Self.title)
                    .ocrFont(Metrics.titleStyle)
                    .foregroundStyle(Theme.medicalNoticeInk)
                    .fixedSize(horizontal: false, vertical: true)
                Text(text)
                    .ocrFont(Metrics.bodyStyle)
                    // Legal copy, so line-height 1.6 — the same ratio the
                    // disclaimer sheet and the old footnotes set it at. The
                    // wording is unchanged from those surfaces; the typesetting
                    // should be too.
                    .ocrFootnoteLeading(size: Metrics.bodyStyle.size)
                    .foregroundStyle(Theme.textPrimary)
                    .fixedSize(horizontal: false, vertical: true)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        .padding(.vertical, Metrics.verticalPadding)
        .padding(.horizontal, Metrics.horizontalPadding)
        .frame(maxWidth: .infinity, alignment: .leading)
        // No `frame(height:)` anywhere: the notice is sized by its copy, so it
        // grows with Dynamic Type instead of clipping the sentence that matters
        // most in the product.
        //
        // An opaque fill, not a material — `Theme.medicalNoticeFill` is the
        // resolved value of a 6% red wash rather than a translucent one — so
        // there is nothing here for Reduce Transparency to turn off and no
        // fallback branch to keep in sync. It is also, by construction, darker
        // than `Theme.surface`, so the notice never reads as a card raised off
        // the page.
        .background(Theme.medicalNoticeFill, in: .rect(cornerRadius: Metrics.corner))
        .overlay {
            RoundedRectangle(cornerRadius: Metrics.corner)
                .strokeBorder(Theme.medicalNoticeBorder, lineWidth: Metrics.stroke)
                // Decorative and inert, matching every other overlay in the
                // package: it must not swallow a tap meant for whatever the
                // notice is stacked with.
                .allowsHitTesting(false)
                .accessibilityHidden(true)
        }
        // One element, read as one statement: "Not a medical diagnosis, <the
        // disclaimer>". No trait is added — the notice is not a button, and a
        // reader who is told it is will try to act on it.
        .accessibilityElement(children: .combine)
    }

    // The glyph tracks its title's size, so the pair stays in proportion at
    // every Dynamic Type setting rather than the words growing around a pinned
    // triangle. `.headline` is the curve `Metrics.titleStyle` (`.cardTitle`)
    // scales on, which is what keeps the two locked together.
    @ScaledMetric(relativeTo: .headline) private var iconSize: CGFloat = 15.5

    /// The notice's fixed metrics. Constants rather than a stored value: there
    /// is exactly one way to draw this object (see the type doc), so there is
    /// nothing for a call site to vary and nothing here to branch on.
    private enum Metrics {
        static let titleStyle: OCRTextStyle = .cardTitle
        static let bodyStyle: OCRTextStyle = .body
        static let corner = Theme.cardCorner
        static let stroke: CGFloat = 1.5
        static let gap: CGFloat = 11
        static let titleGap: CGFloat = 5
        static let verticalPadding = Theme.spacingM
        static let horizontalPadding: CGFloat = 18
    }
}

// MARK: - Result-surface lead

/// The disclaimer as the two *result* surfaces carry it: one sentence at the
/// top of the sheet, in the app's warning form, with the full statement one tap
/// away.
///
/// # Why the result sheets do not render the full notice inline
///
/// They used to, and it was too much. A reader who reaches a result has already
/// passed the blocking first-launch gate carrying all of
/// `MedicalDisclaimer.full`; the sheet then stacked a lead sentence, a demo
/// notice, a professional-care callout and all five paragraphs of `.full` again.
/// `MedicalDisclaimer`'s own design note is the argument against that — "a wall
/// of warnings trains people to skip all of them" — and the result sheet is
/// precisely where being skipped costs the most.
///
/// So the budget for a results surface is **one object**: this one. It carries
/// `MedicalDisclaimer.resultLead` verbatim, in the same red frame and the same
/// warning glyph the notice uses, at the top of the sheet where the number is
/// read — not at the foot, which is not where anyone decides what a result
/// means. The complete statement is a tap away in `MedicalDisclaimerSheet`,
/// which is the same sheet Home and Settings open and the same text the gate
/// showed. Nothing is lost; what changes is that the sentence at the moment of
/// consequence is now the *only* thing competing for that moment.
///
/// The link is visible and underlined rather than left implicit in a tappable
/// panel: a bordered rectangle that happens to accept a tap does not tell
/// anyone there is more to read.
///
/// The copy is a `MedicalDisclaimer` constant passed whole. It is not
/// paraphrased, shortened or line-limited here, and it must not be.
struct OCRResultDisclaimerLead: View {
    /// Opens the full notice. Both call sites present `MedicalDisclaimerSheet`.
    let onReadFull: () -> Void

    /// Tracks the sentence beside it, like every other glyph-and-text pair in
    /// the package.
    @ScaledMetric(relativeTo: .body) private var iconSize: CGFloat = 15

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            HStack(alignment: .firstTextBaseline, spacing: 10) {
                Image(systemName: "exclamationmark.triangle.fill")
                    .font(.system(size: iconSize, weight: .semibold))
                    .foregroundStyle(Theme.medicalNoticeInk)
                    // Decorative: the sentence beside it says the same thing in
                    // words, so VoiceOver gains nothing from "warning, triangle".
                    .accessibilityHidden(true)
                Text(MedicalDisclaimer.resultLead)
                    .ocrFont(.body)
                    .ocrBodyLeading(size: OCRTextStyle.body.size)
                    .foregroundStyle(Theme.textPrimary)
                    .fixedSize(horizontal: false, vertical: true)
                    .frame(maxWidth: .infinity, alignment: .leading)
            }
            .accessibilityElement(children: .combine)

            Button(action: onReadFull) {
                Text("Read the full notice")
                    .ocrFont(.body.size(14))
                    .underline()
                    .foregroundStyle(Theme.accent)
                    .fixedSize(horizontal: false, vertical: true)
                    // 44pt row rather than a 17pt line with negative padding
                    // around it: this is the route to the complete statement, so
                    // it is the one affordance here that must never be fiddly.
                    .frame(maxWidth: .infinity, minHeight: Theme.minTarget, alignment: .leading)
                    .contentShape(.rect)
            }
            .buttonStyle(.plain)
            .accessibilityHint("Opens the full medical disclaimer.")
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 12)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Theme.medicalNoticeFill, in: .rect(cornerRadius: Theme.rowCorner))
        .overlay {
            RoundedRectangle(cornerRadius: Theme.rowCorner)
                .strokeBorder(Theme.medicalNoticeBorder, lineWidth: 1.5)
                .allowsHitTesting(false)
                .accessibilityHidden(true)
        }
    }
}

#Preview("Result disclaimer lead") {
    VStack(spacing: Theme.spacingL) {
        OCRResultDisclaimerLead(onReadFull: {})
    }
    .padding(Theme.pageMargin)
    .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
    .background { OCRAmbientBackground() }
    .preferredColorScheme(.dark)
}

#Preview("Medical notice") {
    ScrollView {
        VStack(spacing: Theme.spacingL) {
            // On the canvas, which is where every screen that carries the
            // notice places it: Home and Settings on their page background, the
            // Result and scan-detail sheets on `OCRAmbientBackground()` /
            // `presentationBackground(Theme.canvas)`.
            VStack(spacing: Theme.spacingM) {
                Text("On Theme.canvas")
                    .ocrFont(.sectionLabel)
                    .foregroundStyle(Theme.textTertiary)
                    .frame(maxWidth: .infinity, alignment: .leading)
                // Both canonical strings, so the wrapping case and the short
                // case are visible side by side.
                OCRMedicalNotice(MedicalDisclaimer.full)
                OCRMedicalNotice(MedicalDisclaimer.short)
            }

            // On a card — no screen does this today, but the fill nearly
            // vanishes against `Theme.surface` by design and the border has to
            // carry the object on its own, so it is worth being able to see.
            VStack(spacing: Theme.spacingM) {
                Text("On Theme.surface")
                    .ocrFont(.sectionLabel)
                    .foregroundStyle(Theme.textTertiary)
                    .frame(maxWidth: .infinity, alignment: .leading)
                OCRMedicalNotice(MedicalDisclaimer.full)
            }
            .padding(Theme.spacingM)
            .background(Theme.surface, in: .rect(cornerRadius: Theme.cardCorner))
        }
        .padding(Theme.pageMargin)
    }
    .frame(maxWidth: .infinity, maxHeight: .infinity)
    .background { OCRAmbientBackground() }
    .preferredColorScheme(.dark)
}
