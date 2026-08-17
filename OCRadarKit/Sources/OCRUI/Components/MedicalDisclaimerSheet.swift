import OCRCore
import SwiftUI

/// The full medical notice as a bottom sheet (design §7).
///
/// One component serves all three presentations — the first-launch
/// acknowledgement gate in `RootView`, and the re-read openings from Home's
/// footnote link and Settings' Support row. They were built independently and
/// had drifted apart (different body colours, leading, footer buttons and
/// detents for what is one screen); only the title and the footer label differ
/// by design.
///
/// The body copy is always `MedicalDisclaimer.full`, never paraphrased
/// (honesty rule 4). Callers vary `actionTitle` because the gate's
/// "I understand" sets `hasAcknowledgedDisclaimer` while a re-read's "Done"
/// must not look like it re-arms it.
struct MedicalDisclaimerSheet: View {
    /// The design pins the sheet at 582 tall.
    static let detentHeight: CGFloat = 582

    /// Sheet fill — one step above `Theme.canvas`, so the sheet reads as a
    /// layer lifted off it. Not a `Theme` token because nothing else uses it.
    ///
    /// The design's `#0A0A0C` was a near-neutral sitting L\* 2.8 above a pure
    /// black canvas. Both halves of that have moved: the canvas is now
    /// `#0F0D14` (L\* 4.0) and the ramp is violet ink, so a neutral fill here
    /// would be the one surface in the app still reading as inherited grey —
    /// and at L\* 2.8 it would now be *darker* than the canvas it is meant to
    /// float above. `#15131C` re-solves it at the family's hue through
    /// `Theme`'s own derivation rule (`4.0 + 0.85 × old` → L\* 6.4), which
    /// keeps the sheet clear of the canvas below it and clear of
    /// `Theme.surface` (9.1) above it. White measures 18.4:1 on it.
    static let background = Color(hex: 0x15131C)

    /// Body copy colour, from the design. Lighter than `textSecondary`
    /// because it sits on the raised sheet fill rather than on the canvas.
    /// Re-solved at the ink family's hue at the design's exact lightness
    /// (L\* 69.1 vs `#A8A8AE`'s 69.0) — 7.8:1 on `background`.
    private static let bodyColor = Color(hex: 0xAAA7B5)

    /// Carried by Home's inline "Read the full notice" link and intercepted by
    /// a local `OpenURLAction` — it never reaches the system. The fallback
    /// keeps the link tappable without a force unwrap.
    static let linkURL: URL = URL(string: "ocradar://disclaimer")
        ?? URL(fileURLWithPath: "/disclaimer")

    let title: String
    let actionTitle: String
    let onAction: () -> Void

    @Environment(\.ocrLogo) private var logo

    var body: some View {
        VStack(spacing: 0) {
            header
            ScrollView {
                Text(MedicalDisclaimer.full)
                    .font(.system(size: 15))
                    // CSS line-height 1.6 at 15pt: ~24pt of leading, of which
                    // SwiftUI already draws ~18. Named as the ratio so it
                    // stays 1.6 at every Dynamic Type size, and so it cannot
                    // drift from the same copy set on Home and in Settings.
                    .ocrFootnoteLeading(size: 15)
                    .foregroundStyle(Self.bodyColor)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(.horizontal, Theme.pageMargin)
                    .padding(.top, Theme.spacingL)
                    // Deeper than the 24 above it: the soft bottom edge effect
                    // below dissolves the last few points of the scroll view,
                    // and this is legal copy — the closing line has to clear
                    // the fade completely, not sit in it.
                    .padding(.bottom, Theme.spacingXL)
            }
            .scrollIndicators(.hidden)
            // The notice runs under the "I understand" footer rather than
            // stopping dead above it, so there is a visible cue that the copy
            // continues. Bottom only: a soft top edge would fade the notice's
            // opening line under the gradient header.
            .scrollEdgeEffectStyle(.soft, for: .bottom)
            Button(actionTitle, action: onAction)
                .buttonStyle(OCRPrimaryButtonStyle())
                .padding(.horizontal, Theme.pageMargin)
                .padding(.bottom, 30)
                // 30 from the bottom of the sheet, as measured — not 30 above
                // the home indicator, which stacked to 66 and left the footer
                // floating. The capsule still clears the indicator: its bottom
                // edge lands above it.
                .ignoresSafeArea(.container, edges: .bottom)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
        // The same ambient plane every other full-height surface in the app
        // sits on, over this sheet's own fill rather than the canvas. Without
        // it the first-launch gate — the first screen anyone ever sees — was
        // the one full-height surface in the app with no bloom and no tooth, a
        // flat rectangle beneath a lit header, which contradicted both
        // `RootView`'s "every screen paints its own ambient background" and
        // `OCRGrainField`'s own note about holding the grain's density on this
        // 582pt sheet. The bloom is well past its peak by the time it clears
        // the header, so what lands here is the faint tail of it plus the
        // grain: the sheet reads as the same material, not as a new one.
        .background { OCRAmbientBackground(fill: Self.background) }
    }

    private var header: some View {
        VStack(alignment: .leading, spacing: 0) {
            // The design draws its own grab handle, so the presentation's is
            // hidden at every call site.
            Capsule()
                .fill(.white.opacity(0.4))
                .frame(width: 44, height: 5)
                .frame(maxWidth: .infinity)
                .padding(.bottom, 22)
                .accessibilityHidden(true)
            logoMark
                .padding(.bottom, Theme.spacingM)
            Text(title)
                .font(.ocrScreenTitle())
                .tracking(-0.7)
                .foregroundStyle(Theme.onGradient())
                .fixedSize(horizontal: false, vertical: true)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.horizontal, Theme.pageMargin)
        .padding(.top, Theme.pageMargin)
        .padding(.bottom, Theme.spacingL)
        .background {
            // Gradient plus the concentric rings that bleed off the top-right,
            // echoing the logo's radar rings — the same pair the hero and the
            // header bands draw. They sit behind the content; the outer clip
            // trims the bleed.
            ZStack(alignment: .topTrailing) {
                Theme.band
                OCRPanelRings(outerDiameter: 190, outerOffset: CGSize(width: 56, height: -60))
            }
            .accessibilityHidden(true)
        }
        .clipped()
        // The header spills light onto the sheet fill below it rather than
        // ending at a cut edge, matching every other gradient panel.
        .ocrPanelSpill()
    }

    @ViewBuilder
    private var logoMark: some View {
        if let logo {
            logo
                .resizable()
                .scaledToFill()
                .frame(width: 46, height: 46)
                .clipShape(.circle)
                .accessibilityHidden(true)
        } else {
            Image(systemName: "circle.circle")
                .font(.system(size: 46))
                .foregroundStyle(Theme.accent)
                .frame(width: 46, height: 46)
                .accessibilityHidden(true)
        }
    }
}

extension View {
    /// The presentation treatment the design pins for the disclaimer sheet:
    /// 582 tall with `.large` kept as the escape hatch at accessibility text
    /// sizes, 30pt top corners, and the system drag indicator hidden because
    /// the sheet draws its own handle.
    func medicalDisclaimerPresentation() -> some View {
        presentationDetents([.height(MedicalDisclaimerSheet.detentHeight), .large])
            .presentationDragIndicator(.hidden)
            .presentationCornerRadius(Theme.sheetCorner)
            .presentationBackground(MedicalDisclaimerSheet.background)
    }
}
