import OCRCore
import SwiftUI

/// Settings tab: model details, the class taxonomy and its risk tiers, the
/// privacy statement, support contact, app info, and the full medical
/// disclaimer.
///
/// Built by hand rather than with a grouped `List` — the design calls for
/// flat opaque cards on a true-black canvas under a gradient header band.
struct SettingsView: View {
    @Environment(\.lesionClassifier) private var classifier

    @State private var isShowingDisclaimer = false

    /// Clears the floating tab bar (62 tall, 30 from the bottom) plus a
    /// comfortable gap so the last row is never trapped underneath it.
    private let bottomClearance: CGFloat = 130

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
                .padding(.top, Theme.pageMargin)
                .padding(.bottom, bottomClearance)
            }
        }
        .scrollIndicators(.hidden)
        .ocrQAScrollBottom()
        .ocrFlushTop()
        .background(Theme.canvas)
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

    private var privacyGroup: some View {
        VStack(alignment: .leading, spacing: Theme.spacingS) {
            OCRSectionLabel("Privacy")
            OCRCard {
                VStack(alignment: .leading, spacing: 9) {
                    HStack(spacing: 12) {
                        Image(systemName: "lock.shield")
                            .font(.system(size: 19))
                            .foregroundStyle(Theme.accent)
                            .accessibilityHidden(true)
                        Text("On-device only")
                            .font(.system(size: 16, weight: .semibold))
                            .tracking(-0.2)
                            .foregroundStyle(Theme.textPrimary)
                    }
                    Text("All analysis happens on this device. Photos and results never leave your iPhone unless you share them.")
                        .font(.system(size: 14))
                        .lineSpacing(7)
                        .foregroundStyle(Theme.textSecondary)
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
            .lineSpacing(8)
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

private nonisolated enum SettingsMetrics {
    static let horizontalPadding: CGFloat = 18
    static let iconWidth: CGFloat = 21
    static let iconGap: CGFloat = 14
    /// 18 + 21 + 14 — a divider between rows that carry a leading icon
    /// starts where the row's text starts.
    static let iconRowInset: CGFloat = horizontalPadding + iconWidth + iconGap
    /// Rows without an icon inset their divider by the row padding alone.
    static let plainRowInset: CGFloat = horizontalPadding
}

/// A 54pt list row: optional leading accent icon, title, trailing value.
private struct SettingsValueRow: View {
    let icon: String?
    let title: String
    let value: String

    var body: some View {
        HStack(spacing: SettingsMetrics.iconGap) {
            if let icon {
                Image(systemName: icon)
                    .font(.system(size: 19))
                    .foregroundStyle(Theme.accent)
                    .frame(width: SettingsMetrics.iconWidth)
                    .accessibilityHidden(true)
            }
            Text(title)
                .font(.ocrRowTitle())
                .tracking(-0.2)
                .foregroundStyle(Theme.textPrimary)
            Spacer(minLength: Theme.spacingS)
            Text(value)
                .font(.system(size: 16))
                .foregroundStyle(Theme.textSecondary)
                .multilineTextAlignment(.trailing)
        }
        .padding(.horizontal, SettingsMetrics.horizontalPadding)
        .frame(minHeight: Theme.rowHeight)
        .accessibilityElement(children: .combine)
    }
}

/// A 54pt list row that goes somewhere: leading accent icon, title, chevron.
private struct SettingsNavigationRow: View {
    let icon: String
    let title: String

    var body: some View {
        HStack(spacing: SettingsMetrics.iconGap) {
            Image(systemName: icon)
                .font(.system(size: 19))
                .foregroundStyle(Theme.accent)
                .frame(width: SettingsMetrics.iconWidth)
                .accessibilityHidden(true)
            Text(title)
                .font(.ocrRowTitle())
                .tracking(-0.2)
                .foregroundStyle(Theme.textPrimary)
            Spacer(minLength: Theme.spacingS)
            Image(systemName: "chevron.right")
                .font(.system(size: 14, weight: .semibold))
                .foregroundStyle(Theme.chevron)
                .accessibilityHidden(true)
        }
        .padding(.horizontal, SettingsMetrics.horizontalPadding)
        .frame(minHeight: max(Theme.rowHeight, Theme.minTarget))
        .contentShape(Rectangle())
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
