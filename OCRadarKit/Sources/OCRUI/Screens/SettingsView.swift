import OCRCore
import SwiftUI

/// Settings tab: model details, the class taxonomy and its risk tiers, the
/// privacy statement, support contact, app info, and the full medical
/// disclaimer.
///
/// Built by hand rather than with a grouped `List`. This is the screen a
/// stock `Form` would have been easiest on and would have hurt most: inset
/// grouped styling is the single most recognisable "iOS default" surface there
/// is, and it would have put Apple's grey plates and full-width hairlines on
/// the one screen that is nothing but plates and hairlines. Every group here is
/// an ink card with a lit top edge and its own inset hairlines, under the
/// gradient header band.
struct SettingsView: View {
    @Environment(\.lesionClassifier) private var classifier

    @State private var isShowingDisclaimer = false

    private let supportURL = URL(string: "mailto:contact@ocradar.com")

    var body: some View {
        ScrollView {
            VStack(spacing: 0) {
                OCRHeaderBand(
                    title: "Settings",
                    subtitle: "Model, privacy and support"
                ) {
                    EmptyView()
                }

                VStack(alignment: .leading, spacing: Theme.spacingL) {
                    modelGroup
                    classesGroup
                    privacyGroup
                    supportGroup
                    aboutGroup
                    // `spacingL` from the About card like every other sibling
                    // in this stack. The old footnote took an extra `spacingXS`
                    // on top of that, which a loose run of grey text needed to
                    // separate itself from the card above it; a bordered object
                    // separates itself, and the nudge would now make the notice
                    // the one sibling sitting at an odd gap.
                    medicalNotice
                }
                .padding(.horizontal, Theme.pageMargin)
                // `spacingL`, the same value Home and History now put under
                // their headers and the same one this stack already uses
                // between its groups. Three tabs used to name this one
                // relationship three ways (34 / 26 / 24), so the first line of
                // content jumped as the user moved between them.
                .padding(.top, Theme.spacingL)
                .padding(.bottom, Theme.tabBarClearance)
            }
        }
        .scrollIndicators(.hidden)
        .ocrQAScrollBottom()
        // Gradient band at the top, floating tab bar at the bottom — top edge
        // effect off at rest and back once the page scrolls, bottom one soft.
        // `Theme.tabBarClearance` still keeps the medical notice reachable
        // above the bar — the effect changes how content looks under the
        // chrome, not whether it can be reached.
        .ocrScrollEdges()
        .background { OCRAmbientBackground() }
        .sheet(isPresented: $isShowingDisclaimer) {
            // Honesty rule 4: the copy is `MedicalDisclaimer.full` and nothing
            // else. Titled "Medical disclaimer" with a "Done" footer, not the
            // gate's "Before you begin" / "I understand" — this is a re-read
            // and must not look like it re-arms `hasAcknowledgedDisclaimer`.
            MedicalDisclaimerSheet(
                title: "Medical disclaimer",
                actionTitle: "Done",
                onAction: { isShowingDisclaimer = false }
            )
            .medicalDisclaimerPresentation()
        }
    }

    // MARK: - Model

    /// Honesty rule 1: the engine and version rows read from the live
    /// classifier, so this surface can never claim a trained model is
    /// installed while Home, History or a detail sheet says otherwise.
    private var modelGroup: some View {
        VStack(alignment: .leading, spacing: Theme.spacingS) {
            OCRSectionLabel("Model")
            OCRCard(padding: 0) {
                VStack(spacing: 0) {
                    SettingsValueRow(
                        icon: "cpu",
                        title: "Engine",
                        value: classifier.kind == .mock ? "Demo" : "Core ML"
                    )
                    SettingsDivider(inset: SettingsMetrics.iconRowInset)
                    SettingsValueRow(
                        icon: "number",
                        title: "Version",
                        value: classifier.manifest.modelVersion
                    )
                }
            }
        }
    }

    // MARK: - Classes & risk tiers

    /// Driven entirely by `ModelManifest.classes` — the taxonomy is never
    /// hardcoded here (honesty rule 5).
    private var classesGroup: some View {
        VStack(alignment: .leading, spacing: Theme.spacingS) {
            OCRSectionLabel("Classes & risk tiers")
            OCRCard {
                VStack(spacing: 13) {
                    ForEach(classifier.manifest.classes) { classInfo in
                        // Name and tier read across a line while they fit and
                        // stack when they do not. The tier used to be pinned to
                        // its intrinsic width, which at accessibility sizes is
                        // a demand the row cannot meet and cannot refuse.
                        ViewThatFits(in: .horizontal) {
                            classRow(
                                classInfo,
                                layout: AnyLayout(
                                    HStackLayout(alignment: .firstTextBaseline, spacing: 12)
                                ),
                                isStacked: false
                            )
                            classRow(
                                classInfo,
                                layout: AnyLayout(
                                    VStackLayout(alignment: .leading, spacing: 2)
                                ),
                                isStacked: true
                            )
                        }
                    }
                }
            }
        }
    }

    /// One class and its risk tier, in whichever arrangement fits.
    ///
    /// `isStacked` is not cosmetic: `ViewThatFits` builds both branches from
    /// this one body, so anything sized for the across-the-line case silently
    /// applies to the stacked one too, where it is usually wrong.
    ///
    /// - The `Spacer` is what pushes the tier to the trailing edge *across* a
    ///   line. In the `VStackLayout` branch it becomes a vertical spacer, and
    ///   since the stack is sized to its ideal height it resolves to its 12pt
    ///   minimum — so the declared `spacing: 2` was dead and the real gap
    ///   between a class name and its tier was ~14pt.
    /// - `lineLimit(1)` is what makes the horizontal branch report an honest
    ///   single-line width, which is how `ViewThatFits` knows to fall back. The
    ///   stacked branch is precisely the case where the tier has the card's
    ///   full width to itself and must be allowed to wrap: at AX5 "Moderate
    ///   risk" measures wider than an `OCRCard` on a 375pt device, and clipping
    ///   it to "Moderate ri…" loses an honesty surface (`RiskLevel.displayLabel`
    ///   is documented in `OCRMetaLine` as never abbreviated). Same treatment
    ///   `HistoryRow` gives the class name it stacks.
    private func classRow(
        _ classInfo: ModelManifest.ClassInfo,
        layout: AnyLayout,
        isStacked: Bool
    ) -> some View {
        layout {
            Text(classInfo.displayName)
                .ocrFont(.listValue)
                .foregroundStyle(Theme.numeralMuted)
            if !isStacked {
                Spacer(minLength: 12)
            }
            Text(classInfo.riskLevel.displayLabel)
                .ocrFont(.body.size(14))
                .foregroundStyle(Theme.textSecondary)
                .lineLimit(isStacked ? nil : 1)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .accessibilityElement(children: .combine)
    }

    // MARK: - Privacy

    /// The one card on this screen whose copy hangs *under* its title rather
    /// than beside it, so it is the one that has to state the icon rail
    /// explicitly instead of getting it from `SettingsValueRow`.
    ///
    /// It used to indent the title by a bare `HStack` and leave the paragraph on
    /// the card's own padding, which put a 31pt ragged edge inside a single card
    /// and set the title ~3pt off the rail every other row on the screen sits
    /// on. Title and body now both hang off `SettingsMetrics.iconRowInset`, the
    /// same rail the dividers two cards above are drawn to.
    private var privacyGroup: some View {
        VStack(alignment: .leading, spacing: Theme.spacingS) {
            OCRSectionLabel("Privacy")
            OCRCard {
                HStack(alignment: .firstTextBaseline, spacing: SettingsMetrics.iconGap) {
                    OCRRowIcon(systemName: "lock.shield")
                    VStack(alignment: .leading, spacing: 9) {
                        Text("On-device only")
                            .ocrFont(.rowTitle.weight(.semibold))
                            .tracking(-0.2)
                            .foregroundStyle(Theme.textPrimary)
                        Text("All analysis happens on this device. Photos and results never leave your iPhone unless you share them.")
                            .ocrFont(.body.size(14))
                            .ocrBodyLeading(size: 14)
                            .foregroundStyle(Theme.textSecondary)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                }
                .accessibilityElement(children: .combine)
            }
        }
    }

    // MARK: - Support

    private var supportGroup: some View {
        VStack(alignment: .leading, spacing: Theme.spacingS) {
            OCRSectionLabel("Support")
            OCRCard(padding: 0) {
                VStack(spacing: 0) {
                    if let supportURL {
                        Link(destination: supportURL) {
                            SettingsNavigationRow(icon: "envelope", title: "Contact support")
                        }
                        .buttonStyle(.plain)
                        SettingsDivider(inset: SettingsMetrics.iconRowInset)
                    }
                    Button {
                        isShowingDisclaimer = true
                    } label: {
                        SettingsNavigationRow(icon: "doc.text", title: "Medical disclaimer")
                    }
                    .buttonStyle(.plain)
                }
            }
        }
    }

    // MARK: - About

    private var aboutGroup: some View {
        VStack(alignment: .leading, spacing: Theme.spacingS) {
            OCRSectionLabel("About")
            OCRCard(padding: 0) {
                VStack(spacing: 0) {
                    SettingsValueRow(icon: nil, title: "App version", value: appVersion)
                    SettingsDivider(inset: SettingsMetrics.plainRowInset)
                    SettingsValueRow(icon: nil, title: "Copyright", value: "© 2026 OCRadar")
                }
            }
        }
    }

    // MARK: - Medical notice

    /// Honesty rule 4: disclaimer copy is never written here, only sourced.
    /// `MedicalDisclaimer.short`, the same string Home sets, verbatim.
    ///
    /// Full weight, on the screen where a quieter treatment would have been
    /// easiest to justify — and `OCRMedicalNotice` has no quieter treatment to
    /// reach for. Settings is where a reader goes *looking* for terms — the
    /// Support group directly above ends in a "Medical disclaimer" row — so a
    /// reader who has scrolled this far has already shown they want the notice,
    /// and meeting them with the faintest ink in the palette was the old
    /// behaviour's real failure. Drawing the one object also makes this
    /// identical to what they will have seen on Home rather than a third
    /// rendering of the same sentence.
    ///
    /// No button here, unlike Home's: the row above already opens the full
    /// sheet, and a second, differently-shaped tap target for it would be one
    /// affordance too many on a screen made of rows. `OCRMedicalNotice` adds no
    /// trait of its own, so VoiceOver reads this as the statement it is.
    ///
    /// Typography, leading and colour all now live in the component, which is
    /// the point: this screen can no longer drift from Home the way it did when
    /// the two set the same string at 1.81 and 1.50 line-height.
    private var medicalNotice: some View {
        OCRMedicalNotice(MedicalDisclaimer.short)
    }

    private var appVersion: String {
        let info = Bundle.main.infoDictionary
        let version = info?["CFBundleShortVersionString"] as? String ?? "1.0"
        if let build = info?["CFBundleVersion"] as? String {
            return "\(version) (\(build))"
        }
        return version
    }
}

// MARK: - Row primitives

/// Main-actor isolated (the module default) rather than `nonisolated`, because
/// `iconWidth` is derived from `OCRRowIcon.box` rather than re-declaring the
/// number beside it. Every reader is a view body, so the isolation costs
/// nothing and the rail can only have one definition.
private enum SettingsMetrics {
    static let horizontalPadding: CGFloat = 18
    /// The shared optical rail every leading glyph in the app is drawn in, so
    /// this screen's divider inset is derived from the icon rather than
    /// re-declared beside it.
    static let iconWidth: CGFloat = OCRRowIcon.box
    static let iconGap: CGFloat = 14
    /// 18 + 21 + 14 — a divider between rows that carry a leading icon
    /// starts where the row's text starts.
    static let iconRowInset: CGFloat = horizontalPadding + iconWidth + iconGap
    /// Rows without an icon inset their divider by the row padding alone.
    static let plainRowInset: CGFloat = horizontalPadding
    /// Where a value sits when it has dropped below its own label: on the same
    /// text rail the label starts on, so the pair still reads as one row.
    static let iconStackInset: CGFloat = iconWidth + iconGap
}

/// A 54pt list row: optional leading accent icon, title, trailing value.
///
/// Baseline-aligned rather than centre-aligned, which is what lets the leading
/// glyph anchor to the title's cap band instead of to the row box. On a
/// single-line row the two land in the same place; the alignment is what keeps
/// that true when Dynamic Type grows the title past the glyph.
private struct SettingsValueRow: View {
    let icon: String?
    let title: String
    let value: String

    /// A label and its value share a line only while there is a line to share.
    /// At accessibility sizes "Engine" and "Demo" each need most of the width,
    /// and side by side neither got it: both broke *mid-word* — "Engin / e",
    /// "Versi / on" — which is not a wrap, it is a word coming apart.
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize

    var body: some View {
        let isStacked = dynamicTypeSize.isAccessibilitySize
        let layout = isStacked
            ? AnyLayout(VStackLayout(alignment: .leading, spacing: 4))
            : AnyLayout(HStackLayout(alignment: .firstTextBaseline, spacing: SettingsMetrics.iconGap))

        layout {
            HStack(alignment: .firstTextBaseline, spacing: SettingsMetrics.iconGap) {
                if let icon {
                    OCRRowIcon(systemName: icon)
                }
                Text(title)
                    .ocrFont(.rowTitle)
                    .tracking(-0.2)
                    .foregroundStyle(Theme.textPrimary)
            }
            if !isStacked {
                Spacer(minLength: Theme.spacingS)
            }
            Text(value)
                .ocrFont(.rowTitle.weight(.regular))
                // "1.0 (1)" and "© 2026 OCRadar" sit one above the other in a
                // right-aligned column, which is exactly the case the design's
                // monospaced-digit rule is about.
                .monospacedDigit()
                .foregroundStyle(Theme.textSecondary)
                .multilineTextAlignment(isStacked ? .leading : .trailing)
                .padding(.leading, isStacked && icon != nil ? SettingsMetrics.iconStackInset : 0)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.horizontal, SettingsMetrics.horizontalPadding)
        .frame(minHeight: Theme.rowHeight)
        .accessibilityElement(children: .combine)
    }
}

/// A 54pt list row that goes somewhere: leading accent icon, title, chevron.
///
/// Structurally identical to `SettingsValueRow` — same alignment, same gap,
/// same padding, same height expression — with the trailing value replaced by
/// the app's one disclosure chevron. The two used to state their height
/// differently (`max(rowHeight, minTarget)` against `rowHeight`) for the same
/// 54pt result, which is the kind of difference that survives a refactor and
/// then stops being the same number.
private struct SettingsNavigationRow: View {
    let icon: String
    let title: String

    var body: some View {
        HStack(alignment: .firstTextBaseline, spacing: SettingsMetrics.iconGap) {
            OCRRowIcon(systemName: icon)
            Text(title)
                .ocrFont(.rowTitle)
                .tracking(-0.2)
                .foregroundStyle(Theme.textPrimary)
            Spacer(minLength: Theme.spacingS)
            OCRChevron()
        }
        .padding(.horizontal, SettingsMetrics.horizontalPadding)
        .frame(minHeight: Theme.rowHeight)
        .contentShape(.rect)
    }
}

/// The hairline that separates rows inside a group card.
private struct SettingsDivider: View {
    let inset: CGFloat

    var body: some View {
        Rectangle()
            .fill(Theme.divider)
            .frame(height: 1)
            .padding(.leading, inset)
            .accessibilityHidden(true)
    }
}


#Preview {
    SettingsView()
        .environment(\.lesionClassifier, MockLesionClassifier())
        .preferredColorScheme(.dark)
}
