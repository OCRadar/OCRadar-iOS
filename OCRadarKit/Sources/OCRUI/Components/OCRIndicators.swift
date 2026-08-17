import SwiftUI

/// The small status dot: salmon for demo, mint for a live model, accent while
/// analyzing. Purely decorative — every caller states the same fact in text
/// beside it, so the dot is hidden from VoiceOver.
///
/// The pulse runs for as long as its host is on screen (the whole of on-device
/// inference, in the analyzing capsule's case), so Reduce Motion holds the dot
/// at full opacity rather than animating it. Nothing is lost: the adjacent copy
/// already says everything the pulse implies.
struct OCRStatusDot: View {
    var color: Color
    var pulsing: Bool = false
    var diameter: CGFloat = 8

    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    @State private var dim = false

    var body: some View {
        Circle()
            .fill(color)
            .frame(width: diameter, height: diameter)
            .opacity(dim ? 0.3 : 1)
            .onAppear { applyPulseState() }
            .onChange(of: reduceMotion) { _, _ in applyPulseState() }
            .accessibilityHidden(true)
    }

    private func applyPulseState() {
        guard pulsing, !reduceMotion else {
            withAnimation(nil) { dim = false }
            return
        }
        withAnimation(.easeInOut(duration: Theme.pulseDuration)
            .repeatForever(autoreverses: true)) {
            dim = true
        }
    }
}

/// One row of the Result sheet's "All classes" card: class name, percentage,
/// and a 6pt capsule bar on a `surfaceRaised` track.
///
/// `rank` is the index into the already-sorted scores, so rank 0 takes the
/// `barTop` gradient and the rest step down the purple ramp.
struct OCRClassBar: View {
    let name: String
    let probability: Double
    let rank: Int

    private var percentText: String {
        ConfidencePercent.text(probability)
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(alignment: .firstTextBaseline) {
                // Label and value were 15/400 white against 14.5/400 secondary:
                // half a point apart, identical weight. `design/README.md` gives
                // a list value as `15.5–16 / 400–500`, so taking the two ends of
                // that range separates them by size *and* weight *and* colour —
                // the name reads as the label, the number as the datum.
                Text(name)
                    .font(.system(size: 15.5))
                    .foregroundStyle(Theme.textPrimary)
                    .fixedSize(horizontal: false, vertical: true)
                Spacer(minLength: Theme.spacingS)
                Text(percentText)
                    .font(.system(size: 14.5, weight: .medium))
                    .monospacedDigit()
                    .foregroundStyle(Theme.textSecondary)
            }
            bar
        }
        .accessibilityElement(children: .combine)
    }

    private var bar: some View {
        GeometryReader { proxy in
            ZStack(alignment: .leading) {
                Capsule()
                    .fill(Theme.surfaceRaised)
                // The **displayed** percentage, not the raw probability. The
                // label rounds through `ConfidencePercent` and the bar did not,
                // so two rows both labelled "22%" drew bars 1.7pt apart on the
                // same track — visible in the card without measuring, and the
                // one surface bypassing the rounding invariant `Theme` exists
                // to guarantee.
                fill
                    .frame(width: proxy.size.width * CGFloat(ConfidencePercent.value(probability)) / 100)
                    .clipShape(.capsule)
            }
        }
        .frame(height: 6)
        .accessibilityHidden(true)
    }

    @ViewBuilder
    private var fill: some View {
        if rank == 0 {
            Rectangle().fill(Theme.barTop)
        } else {
            // Every class below the top one steps down the ramp; a taxonomy
            // longer than the ramp holds at its darkest step rather than
            // wrapping back to a bright fill.
            let index = min(rank - 1, Theme.barRamp.count - 1)
            Rectangle().fill(Theme.barRamp[index])
        }
    }
}
