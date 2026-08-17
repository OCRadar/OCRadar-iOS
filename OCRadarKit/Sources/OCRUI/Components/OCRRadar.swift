import SwiftUI

/// The app's recurring motif: concentric rings with a sweeping arm. Used behind
/// the Scan reticle, as the History empty-state glyph and as the blocked-camera
/// glyph.
///
/// Keep the sweep and `OCRReticle` in ONE coordinate space — their centres must
/// coincide. Both are `ZStack`-centred, so stacking them is enough.
///
/// Every radius is expressed as a fraction of the *radius* (`diameter / 2`) so
/// the three sizes the design draws all scale from one set of numbers. The
/// design's 250pt radar has rings at r = 118 / 80 / 42, i.e. 0.944 / 0.64 /
/// 0.336 of its 125pt radius; the 66pt glyphs use r = 31 / 20 / 9, which is
/// 0.939 / 0.606 / 0.273 — near enough that one shared set reads correctly at
/// both sizes, and far enough from the 1.0 / 0.678 / 0.356 an earlier draft
/// used that the outer ring was drawn 7pt too wide.
struct OCRRadar: View {
    var diameter: CGFloat = 250
    var sweeping: Bool = true
    var struckThrough: Bool = false   // blocked-camera variant
    var dashedMiddle: Bool = false    // empty-state variant

    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    @State private var angle: Double = 0

    /// Ring radii as fractions of the radius: 118 / 80 / 42 of 125.
    private static let ringScales: [CGFloat] = [0.944, 0.64, 0.336]

    /// Where the arm parks when Reduce Motion is on. Deliberately off the
    /// crosshair's own axes, so the arm still reads as a separate element.
    private static let restingAngle: Double = 45

    private var radius: CGFloat { diameter / 2 }
    /// 1pt on the 250 radar, 1.5 on the 66 glyphs.
    private var hairline: CGFloat { diameter > 120 ? 1 : 1.5 }

    var body: some View {
        ZStack {
            rings
            if sweeping {
                crosshair
                sweepArm
            }
            if dashedMiddle {
                centreDot
            }
            if struckThrough {
                strike
            }
        }
        .frame(width: diameter, height: diameter)
        .accessibilityHidden(true)
    }

    /// The empty-state glyph is outer-solid, middle-dashed, no inner ring — the
    /// centre is a filled dot instead. The other two variants draw all three.
    @ViewBuilder
    private var rings: some View {
        if dashedMiddle {
            ring(Self.ringScales[0], dashed: false)
            ring(Self.ringScales[1], dashed: true)
        } else {
            ForEach(Array(Self.ringScales.enumerated()), id: \.offset) { _, scale in
                ring(scale, dashed: false)
            }
        }
    }

    /// `strokeBorder` draws inward from the frame edge, so the stroke's
    /// centreline sits at `frame / 2 - hairline / 2`. The frame is padded by
    /// one line width to put that centreline on the intended radius.
    private func ring(_ scale: CGFloat, dashed: Bool) -> some View {
        let side = 2 * radius * scale + hairline
        return Circle()
            .strokeBorder(
                Theme.radarRing,
                style: StrokeStyle(
                    lineWidth: hairline,
                    dash: dashed ? [3, 5] : []
                )
            )
            .frame(width: side, height: side)
    }

    /// Vertical and horizontal hairlines spanning the outer ring.
    private var crosshair: some View {
        let span = 2 * radius * Self.ringScales[0]
        return ZStack {
            Rectangle()
                .fill(Theme.radarRing)
                .frame(width: hairline, height: span)
            Rectangle()
                .fill(Theme.radarRing)
                .frame(width: span, height: hairline)
        }
    }

    /// One arm from the centre out to the outer ring, rotating 360° over 4s.
    /// The layout frame stays centred on the `ZStack`, so `rotationEffect`
    /// pivots on the radar's centre even though `offset` has pushed the arm up.
    ///
    /// Continuous rotation is the canonical vestibular trigger and this is the
    /// largest moving element in the app, so Reduce Motion parks the arm
    /// instead — the motif survives without the spin.
    private var sweepArm: some View {
        let length = radius * Self.ringScales[0]
        return Capsule()
            .fill(Theme.accent)
            .frame(width: 2, height: length)
            .offset(y: -length / 2)
            .rotationEffect(.degrees(angle))
            .onAppear { applySweepState() }
            .onChange(of: reduceMotion) { _, _ in applySweepState() }
    }

    /// Starts or cancels the perpetual sweep for the current Reduce Motion
    /// setting. Assigning `angle` without an animation is what clears a running
    /// `repeatForever`, so the toggle takes effect while the radar is on screen.
    private func applySweepState() {
        guard !reduceMotion else {
            withAnimation(nil) { angle = Self.restingAngle }
            return
        }
        withAnimation(nil) { angle = 0 }
        withAnimation(.linear(duration: Theme.sweepDuration)
            .repeatForever(autoreverses: false)) {
            angle = 360
        }
    }

    private var centreDot: some View {
        Circle()
            .fill(Color(hex: 0x4A4A52))
            .frame(width: radius * 0.182, height: radius * 0.182)
    }

    private var strike: some View {
        Capsule()
            .fill(Theme.accent)
            .frame(width: 2.5, height: 2 * radius * 0.857)
            .rotationEffect(.degrees(45))
    }
}

/// Four 26pt corner brackets. Centre this on the radar's centre — the design
/// puts both at y 206 in stage coordinates.
struct OCRReticle: View {
    var cornerLength: CGFloat = 26
    var lineWidth: CGFloat = 2

    var body: some View {
        GeometryReader { proxy in
            let w = proxy.size.width
            let h = proxy.size.height
            ForEach(0..<4, id: \.self) { i in
                let isTop = i < 2
                let isLeading = i % 2 == 0
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
