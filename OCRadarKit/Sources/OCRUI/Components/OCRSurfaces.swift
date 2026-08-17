import SwiftUI

/// Flat opaque card. Replaces the old translucent `GlassCard` treatment — the
/// restyle is deliberately not glassy.
///
/// `padding: 0` is the escape hatch for row groups whose dividers have to run
/// edge to edge; those rows own their own horizontal inset.
struct OCRCard<Content: View>: View {
    var corner: CGFloat = Theme.cardCorner
    var padding: CGFloat = 18
    @ViewBuilder var content: Content

    var body: some View {
        content
            .padding(padding)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(Theme.surface, in: .rect(cornerRadius: corner))
    }
}

/// The 13/600 label that sits above a card group.
struct OCRSectionLabel: View {
    private let text: String

    init(_ text: String) {
        self.text = text
    }

    var body: some View {
        Text(text)
            .font(.ocrSectionLabel())
            .foregroundStyle(Theme.textSecondary)
            .frame(maxWidth: .infinity, alignment: .leading)
    }
}

/// The compact gradient band used by Scan, History and Settings: bottom
/// corners 30, title and subtitle bottom-left, an optional trailing caption
/// bottom-right.
///
/// Two shapes, both measured from the design:
///
/// - **Scan** pins the band to a `fixedHeight` of 150 with its content 22 from
///   the bottom, because the camera stage below it is positioned absolutely
///   (top 166) and would drift if the band grew.
/// - **History and Settings** are content-driven — 96 above the title, 24
///   below the subtitle — which comes out taller than 150. Forcing those to
///   150 crushed the 96pt top inset the design uses to clear the status bar.
///
/// Home and the sheets use the same treatment with a taller body — see
/// `Theme.hero` and `OCRSheetHeader`.
struct OCRHeaderBand<Trailing: View>: View {
    let title: String
    let subtitle: String
    /// 150 for Scan; `nil` lets the 96/24 padding size the band.
    var fixedHeight: CGFloat? = nil
    @ViewBuilder var trailing: Trailing

    var body: some View {
        content
            .background {
                ZStack(alignment: .topTrailing) {
                    Theme.band
                    // Decorative ring echoing the logo's radar rings — bleeds
                    // 56 off the right edge and 52 above the top, trimmed by
                    // the outer clip.
                    Circle()
                        .strokeBorder(.white.opacity(0.14), lineWidth: 1)
                        .frame(width: 190, height: 190)
                        .offset(x: 56, y: -52)
                }
                .accessibilityHidden(true)
            }
            .clipShape(.rect(bottomLeadingRadius: Theme.bandCorner,
                             bottomTrailingRadius: Theme.bandCorner))
            .foregroundStyle(.white)
    }

    @ViewBuilder
    private var content: some View {
        if let fixedHeight {
            // `minHeight`, not `height`: the title and subtitle both scale, and
            // at accessibility sizes the bottom-aligned pair outgrew 150 and was
            // clipped upward by the band's own `clipShape` (sliding under the
            // status bar on the way). `fixedSize` keeps the band at exactly that
            // ideal height instead of letting the flexible frame split the
            // screen with the Scan stage below it; the stage is the flexible
            // one, so a taller band costs stage height, never legibility.
            titleRow
                .padding(.horizontal, Theme.pageMargin)
                .padding(.bottom, 22)
                .frame(
                    maxWidth: .infinity,
                    minHeight: fixedHeight,
                    alignment: .bottomLeading
                )
                .fixedSize(horizontal: false, vertical: true)
        } else {
            titleRow
                .padding(.horizontal, Theme.pageMargin)
                .padding(.top, 96)
                .padding(.bottom, 24)
        }
    }

    private var titleRow: some View {
        HStack(alignment: .bottom) {
            VStack(alignment: .leading, spacing: 6) {
                Text(title)
                    .font(.ocrScreenTitle())
                    .tracking(-0.7)
                Text(subtitle)
                    .font(.ocrMeta())
                    .foregroundStyle(Theme.onGradient())
            }
            .fixedSize(horizontal: false, vertical: true)
            Spacer(minLength: Theme.spacingM)
            trailing
                .font(.system(size: 13))
                .foregroundStyle(Theme.onGradient())
        }
    }
}

/// The gradient header shared by the Result and Scan-detail sheets: an eyebrow
/// and a Done button, then the record's meta line, confidence numeral, class
/// name and risk tier.
///
/// Every value is passed in by the presenting screen so the header can only
/// ever show the record it was given (honesty rule 6).
struct OCRSheetHeader: View {
    let eyebrow: String
    let meta: String
    let percentText: String
    let title: String
    let tierText: String
    let onDone: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            HStack {
                Text(eyebrow)
                    .font(.system(size: 15, weight: .semibold))
                    .tracking(-0.1)
                Spacer(minLength: Theme.spacingM)
                Button(action: onDone) {
                    Text("Done")
                        .font(.system(size: 15, weight: .semibold))
                        .padding(.horizontal, Theme.spacingM)
                        .frame(minWidth: Theme.minTarget, minHeight: 34)
                        .background(.white.opacity(0.2), in: .capsule)
                        // 34pt capsule, 44pt touch target — this is the only
                        // way out of the sheet other than a swipe. The outer
                        // negative padding keeps the capsule on the measured
                        // 22pt top inset, matching the gear button on Home.
                        .frame(minHeight: Theme.minTarget)
                        .contentShape(.rect)
                }
                .buttonStyle(.plain)
                .foregroundStyle(.white)
                .padding(.vertical, -(Theme.minTarget - 34) / 2)
            }
            .padding(.bottom, 30)

            Text(meta)
                .font(.system(size: 13.5, weight: .medium))
                .foregroundStyle(Theme.onGradient())
                .padding(.bottom, 12)

            // The 76pt numeral scales with Dynamic Type; it shrinks rather
            // than clipping when the text size runs away with it.
            Text(percentText)
                .font(.ocrHeroNumeral())
                .tracking(-3.6)
                .monospacedDigit()
                .lineLimit(1)
                .minimumScaleFactor(0.4)
                .ocrHeroLineHeight()
                .padding(.bottom, Theme.spacingS)

            Text(title)
                .font(.ocrScreenTitle())
                .tracking(-0.7)
                .fixedSize(horizontal: false, vertical: true)
                .padding(.bottom, 6)

            Text(tierText)
                .font(.system(size: 15.5))
                .foregroundStyle(Theme.onGradient())
                .fixedSize(horizontal: false, vertical: true)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.horizontal, Theme.pageMargin)
        .padding(.top, 22)
        .padding(.bottom, 30)
        .background {
            ZStack(alignment: .topTrailing) {
                Theme.hero
                Circle()
                    .strokeBorder(.white.opacity(0.14), lineWidth: 1)
                    .frame(width: 220, height: 220)
                    .offset(x: 70, y: -56)
            }
            .accessibilityHidden(true)
        }
        .clipShape(.rect(bottomLeadingRadius: Theme.heroCorner,
                         bottomTrailingRadius: Theme.heroCorner))
        .foregroundStyle(.white)
    }
}

/// Outlined notice marking a demo result. The salmon dot is data-only styling —
/// the copy itself is white and passes contrast on its own.
///
/// `title` and `message` are always supplied in full by the caller; the two
/// sheets word this differently and neither wording may be shortened.
struct OCRDemoNotice: View {
    let title: String
    let message: String

    var body: some View {
        HStack(alignment: .top, spacing: 11) {
            Circle()
                .fill(Theme.salmon)
                .frame(width: 8, height: 8)
                .padding(.top, 6)
                .accessibilityHidden(true)
            copy
        }
        .lineSpacing(4)
        .fixedSize(horizontal: false, vertical: true)
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.vertical, Theme.spacingM)
        .padding(.horizontal, 18)
        .overlay {
            RoundedRectangle(cornerRadius: Theme.rowCorner)
                .strokeBorder(Theme.noticeBorder, lineWidth: 1)
        }
        .accessibilityElement(children: .combine)
    }

    /// The title runs bold-white into the message as one flowing paragraph,
    /// exactly as the design draws it — so it is one `Text`, not two.
    private var copy: Text {
        var notice = AttributedString(title)
        notice.font = .system(size: 13.5, weight: .semibold)
        notice.foregroundColor = Theme.textPrimary
        var rest = AttributedString(" " + message)
        rest.font = .system(size: 13.5)
        rest.foregroundColor = Theme.textSecondary
        notice.append(rest)
        return Text(notice)
    }
}
