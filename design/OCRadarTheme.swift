// OCRadarTheme.swift — starting point for the restyle.
// Values transcribed from the HTML design reference in this bundle.
// Drop into OCRadarKit/Sources/OCRUI/Components/ and replace the existing Theme.

import SwiftUI

nonisolated enum Theme {
    // MARK: Colour
    static let canvas = Color.black
    static let surface = Color(hex: 0x131316)
    static let surfaceRaised = Color(hex: 0x26262C)
    static let tabBarFill = Color(hex: 0x16161A)
    static let divider = Color(hex: 0x1E1E24)

    static let textPrimary = Color.white
    static let textSecondary = Color(hex: 0x8E8E93)   // 6.44:1 on black
    static let textTertiary = Color(hex: 0x76767E)    // 4.60:1 on black — lightest allowed for text
    static let numeralMuted = Color(hex: 0xE8E6EC)
    static let chevron = Color(hex: 0x5A5A62)

    static let accent = Color(hex: 0xC77BE8)
    static let salmon = Color(hex: 0xE39B7B)          // data only, never behind text
    static let mint = Color(hex: 0x5FD3A6)            // live-model indicator

    static let stageFill = Color(hex: 0x0C0C0F)
    static let stageBorder = Color(hex: 0x1C1C22)
    static let radarRing = Color(hex: 0x26262E)

    // MARK: Gradients — sampled from the ocrnew logo asset.
    // The third stop must stay this dark: at #D08A6E white text measured 2.8–3.7:1.
    static let hero = LinearGradient(
        stops: [.init(color: Color(hex: 0x4B2E8F), location: 0),
                .init(color: Color(hex: 0x8B4E9E), location: 0.52),
                .init(color: Color(hex: 0x96554F), location: 1)],
        startPoint: .topLeading, endPoint: .bottomTrailing
    )

    static let band = LinearGradient(
        stops: [.init(color: Color(hex: 0x4B2E8F), location: 0),
                .init(color: Color(hex: 0x8B4E9E), location: 0.62),
                .init(color: Color(hex: 0x96554F), location: 1)],
        startPoint: .topLeading, endPoint: .bottomTrailing
    )

    static let button = LinearGradient(
        colors: [Color(hex: 0x7C3FBF), Color(hex: 0x96554F)],
        startPoint: .topLeading, endPoint: .bottomTrailing
    )

    /// Descending fills for the "All classes" bars — index 0 is the top class.
    static let barRamp: [Color] = [
        Color(hex: 0xB96FDA), Color(hex: 0x8B4E9E), Color(hex: 0x6B3E86),
        Color(hex: 0x553171), Color(hex: 0x4B2E8F)
    ]

    /// Text on any gradient surface: white, never below 92% opacity.
    static func onGradient(_ opacity: Double = 1) -> Color {
        .white.opacity(max(opacity, 0.92))
    }

    // MARK: Radii
    static let heroCorner: CGFloat = 34
    static let bandCorner: CGFloat = 30
    static let sheetCorner: CGFloat = 30
    static let cardCorner: CGFloat = 18
    static let rowCorner: CGFloat = 16
    static let panelCorner: CGFloat = 20
    static let stageCorner: CGFloat = 24

    // MARK: Spacing
    static let pageMargin: CGFloat = 26
    static let stageInset: CGFloat = 16
    static let spacingXS: CGFloat = 4
    static let spacingS: CGFloat = 10
    static let spacingM: CGFloat = 16
    static let spacingL: CGFloat = 24
    static let spacingXL: CGFloat = 34
    static let rowHeight: CGFloat = 54
    static let minTarget: CGFloat = 44

    // MARK: Motion
    static let sheetRise = Animation.timingCurve(0.32, 0.72, 0, 1, duration: 0.42)
    static let sweepDuration: Double = 4
}

extension Color {
    init(hex: UInt32) {
        self.init(.sRGB,
                  red: Double((hex >> 16) & 0xFF) / 255,
                  green: Double((hex >> 8) & 0xFF) / 255,
                  blue: Double(hex & 0xFF) / 255,
                  opacity: 1)
    }
}

// MARK: - Type

extension Font {
    static func ocrHeroNumeral() -> Font { .system(size: 76, weight: .semibold) }
    static func ocrScreenTitle() -> Font { .system(size: 26, weight: .semibold) }
    static func ocrSectionHead() -> Font { .system(size: 21, weight: .semibold) }
    static func ocrCardTitle() -> Font { .system(size: 16.5, weight: .semibold) }
    static func ocrRowTitle() -> Font { .system(size: 16, weight: .medium) }
    static func ocrBody() -> Font { .system(size: 14.5) }
    static func ocrMeta() -> Font { .system(size: 13.5) }
    static func ocrSectionLabel() -> Font { .system(size: 13, weight: .semibold) }
    static func ocrFootnote() -> Font { .system(size: 13) }
}

// Tracking is applied per-site because SwiftUI has no tracking on Font:
//   Text("91%").font(.ocrHeroNumeral()).tracking(-3.6).monospacedDigit()
//   Text("Scan").font(.ocrScreenTitle()).tracking(-0.7)
//   Text("Earlier scans").font(.ocrSectionHead()).tracking(-0.45)

// MARK: - Surfaces

/// Flat opaque card. Replaces the old translucent GlassCard treatment —
/// the design is deliberately not glassy.
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

/// The compact gradient header used by Scan, History and Settings.
/// Home and the sheets use the same treatment with a taller body — see `hero`.
struct OCRHeaderBand<Trailing: View>: View {
    let title: String
    let subtitle: String
    @ViewBuilder var trailing: Trailing

    var body: some View {
        ZStack(alignment: .bottomLeading) {
            Theme.band
            // Decorative ring echoing the logo — bleeds off the top-right.
            Circle()
                .strokeBorder(.white.opacity(0.14), lineWidth: 1)
                .frame(width: 190, height: 190)
                .offset(x: 150, y: -110)
                .accessibilityHidden(true)
            HStack(alignment: .bottom) {
                VStack(alignment: .leading, spacing: 6) {
                    Text(title).font(.ocrScreenTitle()).tracking(-0.7)
                    Text(subtitle).font(.ocrMeta()).foregroundStyle(Theme.onGradient())
                }
                Spacer(minLength: Theme.spacingM)
                trailing
                    .font(.system(size: 13))
                    .foregroundStyle(Theme.onGradient())
            }
            .padding(.horizontal, Theme.pageMargin)
            .padding(.bottom, 22)
        }
        .frame(height: 150)
        .clipShape(.rect(bottomLeadingRadius: Theme.bandCorner,
                         bottomTrailingRadius: Theme.bandCorner))
        .foregroundStyle(.white)
    }
}

/// Filled primary button. White-on-gradient measures >= 5.6:1.
struct OCRPrimaryButtonStyle: ButtonStyle {
    var height: CGFloat = 54
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.system(size: 16.5, weight: .semibold))
            .foregroundStyle(.white)
            .frame(maxWidth: .infinity, minHeight: height)
            .background(Theme.button, in: .capsule)
            .scaleEffect(configuration.isPressed ? 0.99 : 1)
    }
}

/// On the Home hero the primary action inverts to solid white.
struct OCRInverseButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.system(size: 16.5, weight: .semibold))
            .foregroundStyle(Color(hex: 0x2A1745))
            .frame(maxWidth: .infinity, minHeight: 54)
            .background(.white, in: .capsule)
            .scaleEffect(configuration.isPressed ? 0.99 : 1)
    }
}

struct OCRSecondaryButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.system(size: 16, weight: .semibold))
            .foregroundStyle(.white)
            .frame(maxWidth: .infinity, minHeight: 52)
            .background(Theme.surfaceRaised, in: .capsule)
            .scaleEffect(configuration.isPressed ? 0.98 : 1)
    }
}

// MARK: - Floating tab bar
//
// Replaces the system tab bar: keep TabView for state, hide its bar
// (`.toolbar(.hidden, for: .tabBar)`) and overlay this.

struct OCRTabBar: View {
    @Binding var selection: AppTab

    private struct Item { let tab: AppTab; let symbol: String; let label: String }
    private let items: [Item] = [
        .init(tab: .home, symbol: "house.fill", label: "Home"),
        .init(tab: .scan, symbol: "camera.viewfinder", label: "Scan"),
        .init(tab: .history, symbol: "clock.arrow.circlepath", label: "History"),
        .init(tab: .settings, symbol: "gearshape.fill", label: "Settings")
    ]

    var body: some View {
        HStack(spacing: 0) {
            ForEach(items, id: \.tab) { item in
                let isSelected = selection == item.tab
                Button {
                    selection = item.tab
                } label: {
                    VStack(spacing: 2) {
                        Image(systemName: item.symbol).font(.system(size: 21))
                        Text(item.label).font(.system(size: 10))
                    }
                    .foregroundStyle(isSelected ? Theme.textPrimary : Theme.textSecondary)
                    .frame(maxWidth: .infinity, minHeight: 50)
                    .background(isSelected ? Theme.surfaceRaised : .clear, in: .capsule)
                }
                .buttonStyle(.plain)
                .accessibilityLabel(item.label)
                .accessibilityAddTraits(isSelected ? [.isButton, .isSelected] : .isButton)
            }
        }
        .padding(.horizontal, 6)
        .frame(height: 62)
        .background(Theme.tabBarFill, in: .capsule)
        .shadow(color: .black.opacity(0.6), radius: 15, y: 10)
        .padding(.horizontal, 14)
        .padding(.bottom, 30)
    }
}

// MARK: - Radar
//
// The app's recurring motif: concentric rings with a sweeping arm. Used behind
// the Scan reticle, as the empty-state and blocked-camera glyph, and as the
// wordmark accent. Keep the sweep and the reticle in ONE coordinate space —
// their centres must coincide.

struct OCRRadar: View {
    var diameter: CGFloat = 250
    var sweeping: Bool = true
    var struckThrough: Bool = false   // blocked-camera variant
    var dashedMiddle: Bool = false    // empty-state variant

    @State private var angle: Double = 0

    var body: some View {
        ZStack {
            ForEach([1.0, 0.678, 0.356], id: \.self) { scale in
                Circle()
                    .strokeBorder(Theme.radarRing, lineWidth: 1)
                    .frame(width: diameter * scale, height: diameter * scale)
            }
            if dashedMiddle {
                Circle()
                    .strokeBorder(Theme.radarRing,
                                  style: StrokeStyle(lineWidth: 1, dash: [3, 5]))
                    .frame(width: diameter * 0.6, height: diameter * 0.6)
            }
            if sweeping {
                Rectangle()
                    .fill(Theme.accent)
                    .frame(width: 2, height: diameter / 2)
                    .offset(y: -diameter / 4)
                    .rotationEffect(.degrees(angle))
                    .onAppear {
                        withAnimation(.linear(duration: Theme.sweepDuration)
                            .repeatForever(autoreverses: false)) {
                            angle = 360
                        }
                    }
            }
            if struckThrough {
                Capsule()
                    .fill(Theme.accent)
                    .frame(width: 2.5, height: diameter * 0.86)
                    .rotationEffect(.degrees(45))
            }
        }
        .frame(width: diameter, height: diameter)
        .accessibilityHidden(true)
    }
}

/// Four corner brackets. Centre this on the radar's centre.
struct OCRReticle: View {
    var cornerLength: CGFloat = 26
    var lineWidth: CGFloat = 2

    var body: some View {
        GeometryReader { proxy in
            let w = proxy.size.width, h = proxy.size.height
            ForEach(0..<4, id: \.self) { i in
                let isTop = i < 2, isLeading = i % 2 == 0
                Path { p in
                    let x = isLeading ? 0 : w
                    let y = isTop ? 0 : h
                    p.move(to: CGPoint(x: isLeading ? x : x - cornerLength, y: y))
                    p.addLine(to: CGPoint(x: isLeading ? x + cornerLength : x, y: y))
                    p.move(to: CGPoint(x: x, y: isTop ? y : y - cornerLength))
                    p.addLine(to: CGPoint(x: x, y: isTop ? y + cornerLength : y))
                }
                .stroke(Theme.accent, style: StrokeStyle(lineWidth: lineWidth,
                                                         lineCap: .round))
            }
        }
        .accessibilityHidden(true)
    }
}
