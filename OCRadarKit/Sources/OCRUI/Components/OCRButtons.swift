import SwiftUI

/// Filled primary button — the app's default call to action. White on
/// `Theme.button` measures ≥5.6:1.
struct OCRPrimaryButtonStyle: ButtonStyle {
    var height: CGFloat = 54

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.system(size: 16.5, weight: .semibold))
            .foregroundStyle(.white)
            .frame(maxWidth: .infinity, minHeight: height)
            .ocrGradientBackground(Theme.button, in: .capsule)
            .contentShape(.capsule)
            .scaleEffect(configuration.isPressed ? 0.99 : 1)
            .animation(.easeOut(duration: 0.12), value: configuration.isPressed)
    }
}

/// On the Home hero the primary action inverts to solid white, because the
/// gradient button would disappear into the gradient panel behind it.
struct OCRInverseButtonStyle: ButtonStyle {
    var height: CGFloat = 54

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.system(size: 16.5, weight: .semibold))
            .foregroundStyle(Color(hex: 0x2A1745))
            .frame(maxWidth: .infinity, minHeight: height)
            .background(.white, in: .capsule)
            .contentShape(.capsule)
            .scaleEffect(configuration.isPressed ? 0.99 : 1)
            .animation(.easeOut(duration: 0.12), value: configuration.isPressed)
    }
}

/// Secondary capsule on a raised fill — "Retake", "Choose Photo".
struct OCRSecondaryButtonStyle: ButtonStyle {
    var height: CGFloat = 52

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.system(size: 16, weight: .semibold))
            .foregroundStyle(.white)
            .frame(maxWidth: .infinity, minHeight: height)
            .background(Theme.surfaceRaised, in: .capsule)
            .contentShape(.capsule)
            .scaleEffect(configuration.isPressed ? 0.98 : 1)
            .animation(.easeOut(duration: 0.12), value: configuration.isPressed)
    }
}
