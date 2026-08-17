import SwiftUI

/// The press response every button in the app shares: a 1–2% settle on touch
/// down, gated on Reduce Motion.
///
/// It is a `ViewModifier` rather than two lines at each style, because the gate
/// is the point. Every other animation in the package reads
/// `accessibilityReduceMotion` and says why it has to — `OCRRadar`'s sweep,
/// `OCRStatusDot`'s pulse, `OCRTabBar`'s selection chip — and the three button
/// styles were the one family still animating unconditionally, on every primary
/// call to action in the app including the disclaimer gate's "I understand".
///
/// A `ButtonStyle` cannot hold the read itself: SwiftUI only updates dynamic
/// properties on `View`s and `ViewModifier`s, so an `@Environment` stored on the
/// style would be read once at construction and then go stale. Putting it here
/// means the styles get the live value, and get it identically.
///
/// With the setting on the scale is dropped entirely rather than animated to the
/// same place — the press is still legible, because the control's own highlight
/// and the action it triggers are what report it.
private struct OCRPressResponse: ViewModifier {
    let isPressed: Bool
    /// How far the control settles under the finger. 0.99 for the two
    /// full-width filled styles, 0.98 for the secondary.
    let pressedScale: CGFloat

    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    func body(content: Content) -> some View {
        content
            .scaleEffect(reduceMotion || !isPressed ? 1 : pressedScale)
            .animation(reduceMotion ? nil : .easeOut(duration: 0.12), value: isPressed)
    }
}

extension View {
    /// Applies `OCRPressResponse`. Every `ButtonStyle` in the app ends with it.
    fileprivate func ocrPressResponse(
        isPressed: Bool,
        pressedScale: CGFloat
    ) -> some View {
        modifier(OCRPressResponse(isPressed: isPressed, pressedScale: pressedScale))
    }
}

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
            .ocrPressResponse(isPressed: configuration.isPressed, pressedScale: 0.99)
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
            .ocrPressResponse(isPressed: configuration.isPressed, pressedScale: 0.99)
    }
}

/// Secondary capsule on a raised fill — "Retake", "Choose Photo".
///
/// The only flat-filled control in the app, and the one most likely to read as
/// a stock button, so it takes the same lit top edge the cards do. The other
/// two styles are already carrying either the gradient or solid white and would
/// gain nothing from it.
struct OCRSecondaryButtonStyle: ButtonStyle {
    var height: CGFloat = 52

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.system(size: 16, weight: .semibold))
            .foregroundStyle(.white)
            .frame(maxWidth: .infinity, minHeight: height)
            .background(Theme.surfaceRaised, in: .capsule)
            .ocrTopEdgeHighlight(Capsule())
            .contentShape(.capsule)
            .ocrPressResponse(isPressed: configuration.isPressed, pressedScale: 0.98)
    }
}
