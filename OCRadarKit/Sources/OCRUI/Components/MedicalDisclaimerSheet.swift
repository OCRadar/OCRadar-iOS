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

    /// Sheet fill — a hair off pure black so the sheet reads as a layer above
    /// the canvas. Not a `Theme` token because nothing else uses it.
    static let background = Color(hex: 0x0A0A0C)

    /// Body copy colour, from the design. Lighter than `textSecondary`
    /// because it sits on the raised sheet fill rather than on the canvas.
    private static let bodyColor = Color(hex: 0xA8A8AE)

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
                    // SwiftUI already draws ~18.
                    .lineSpacing(6)
                    .foregroundStyle(Self.bodyColor)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(.horizontal, Theme.pageMargin)
                    .padding(.vertical, Theme.spacingL)
            }
            .scrollIndicators(.hidden)
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
        .background(Self.background)
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
            // Gradient plus the decorative ring that bleeds off the top-right,
            // echoing the logo's radar rings. Both sit behind the content; the
            // outer clip trims the bleed.
            ZStack(alignment: .topTrailing) {
                Theme.band
                Circle()
                    .strokeBorder(.white.opacity(0.14), lineWidth: 1)
                    .frame(width: 190, height: 190)
                    .offset(x: 56, y: -60)
            }
            .accessibilityHidden(true)
        }
        .clipped()
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
