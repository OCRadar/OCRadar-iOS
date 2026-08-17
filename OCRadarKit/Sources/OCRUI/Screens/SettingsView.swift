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
                    footnote
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
        // `Theme.tabBarClearance` still keeps the footnote reachable above the
        // bar — the effect changes how content looks under the chrome, not
        // whether it can be reached.
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
                        HStack(alignment: .firstTextBaseline, spacing: 12) {
                            Text(classInfo.displayName)
                                .font(.system(size: 15.5))
                                .foregroundStyle(Theme.numeralMuted)
                            Spacer(minLength: 12)
                            Text(classInfo.riskLevel.displayLabel)
                                .font(.system(size: 14))
                                .foregroundStyle(Theme.textSecondary)
                                .lineLimit(1)
                                .fixedSize(horizontal: true, vertical: false)
                        }
                        .accessibilityElement(children: .combine)
                    }
                }
            }
        }
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
                            .font(.system(size: 16, weight: .semibold))
                            .tracking(-0.2)
                            .foregroundStyle(Theme.textPrimary)
                        Text("All analysis happens on this device. Photos and results never leave your iPhone unless you share them.")
                            .font(.system(size: 14))
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

    // MARK: - Footnote

    /// Honesty rule 4: disclaimer copy is never written here, only sourced.
    private var footnote: some View {
        Text(MedicalDisclaimer.short)
            .font(.ocrFootnote())
            // The same string Home sets. It used to run at 1.81 here and 1.50
            // there; both now run at the type table's footnote ratio.
            .ocrFootnoteLeading(size: 13)
            .foregroundStyle(Theme.textTertiary)
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.top, Theme.spacingXS)
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

    var body: some View {
        HStack(alignment: .firstTextBaseline, spacing: SettingsMetrics.iconGap) {
            if let icon {
                OCRRowIcon(systemName: icon)
            }
            Text(title)
                .font(.ocrRowTitle())
                .tracking(-0.2)
                .foregroundStyle(Theme.textPrimary)
            Spacer(minLength: Theme.spacingS)
            Text(value)
                .font(.system(size: 16))
                // "1.0 (1)" and "© 2026 OCRadar" sit one above the other in a
                // right-aligned column, which is exactly the case the design's
                // monospaced-digit rule is about.
                .monospacedDigit()
                .foregroundStyle(Theme.textSecondary)
                .multilineTextAlignment(.trailing)
        }
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
                .font(.ocrRowTitle())
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
