import SwiftUI

/// The floating capsule tab bar that replaces the system one. Screens extend
/// under it, so it is overlaid on a bottom-aligned `ZStack` by `RootView`
/// rather than reserving a safe-area inset.
///
/// It owns its own 14pt horizontal inset and 30pt bottom offset, so callers add
/// no padding around it. Screens clear it with `Theme.tabBarClearance`.
///
/// The capsule is Liquid Glass: this is the app's most literal piece of
/// chrome — it floats over every screen and content scrolls beneath it, which
/// is the one thing a flat `tabBarFill` could never show. See `OCRGlass.swift`
/// for the tint and Reduce Transparency rules it follows.
struct OCRTabBar: View {
    @Binding var selection: AppTab

    @Environment(\.accessibilityReduceTransparency) private var reduceTransparency

    private struct Item: Identifiable {
        let tab: AppTab
        let symbol: String
        let label: String
        var id: AppTab { tab }
    }

    private let items: [Item] = [
        .init(tab: .home, symbol: "house.fill", label: "Home"),
        .init(tab: .scan, symbol: "camera.viewfinder", label: "Scan"),
        .init(tab: .history, symbol: "clock.arrow.circlepath", label: "History"),
        .init(tab: .settings, symbol: "gearshape.fill", label: "Settings")
    ]

    /// Fill of the selected tab's pill.
    ///
    /// The design's selected pill is `surfaceRaised` — one step *lighter* than
    /// the bar it sits in. That holds as a fixed colour only while the bar is a
    /// fixed colour. On glass the bar moves: untinted it sampled `#363438`,
    /// which is *lighter* than `#26262C`, so the selected tab read as a dark
    /// hole punched in the bar rather than a raised pill — the hierarchy
    /// inverted. A white overlay keeps the relationship the design actually
    /// describes: a step above whatever the material is doing. Against the
    /// shipped bar's `#212125` it samples `#39393D`, a little more separation
    /// than `#26262C` had against the flat `#16161A`, and white on it measures
    /// 11.6:1.
    ///
    /// That reasoning only applies while there *is* a material. With Reduce
    /// Transparency on the bar returns to the flat `tabBarFill` token, so the
    /// pill returns to the flat `surfaceRaised` token it was drawn as — the
    /// same contract every other surface in `OCRGlass.swift` keeps. Left as the
    /// white overlay it composited to roughly `#323235` and the design token was
    /// silently lost in the accessibility path.
    private var selectedPillFill: AnyShapeStyle {
        reduceTransparency
            ? AnyShapeStyle(Theme.surfaceRaised)
            : AnyShapeStyle(.white.opacity(0.12))
    }

    var body: some View {
        HStack(spacing: 0) {
            ForEach(items) { item in
                let isSelected = selection == item.tab
                Button {
                    selection = item.tab
                } label: {
                    VStack(spacing: 2) {
                        Image(systemName: item.symbol)
                            .font(.system(size: 21))
                        Text(item.label)
                            .font(.system(size: 10))
                    }
                    // The bar is a fixed floating capsule that screens clear
                    // with `Theme.tabBarClearance`, so its own type is capped:
                    // unclamped, the 21pt icon plus the 10pt label want ~95pt
                    // at the largest accessibility sizes and would render
                    // outside the capsule, over the screen behind it. The full
                    // label stays available to VoiceOver either way.
                    .dynamicTypeSize(...DynamicTypeSize.accessibility1)
                    .foregroundStyle(isSelected ? Theme.textPrimary : Theme.textSecondary)
                    .frame(maxWidth: .infinity, minHeight: 50)
                    // See `selectedPillFill`.
                    .background(
                        isSelected ? selectedPillFill : AnyShapeStyle(.clear),
                        in: .capsule
                    )
                    .contentShape(.capsule)
                }
                .buttonStyle(.plain)
                .accessibilityLabel(item.label)
                .accessibilityAddTraits(isSelected ? [.isButton, .isSelected] : .isButton)
            }
        }
        .padding(.horizontal, 6)
        .frame(minHeight: 62)
        .fixedSize(horizontal: false, vertical: true)
        // Half-strength `tabBarFill`, not untinted and not the solid token.
        // Both extremes were sampled on the simulator over the Home screen:
        //
        // - untinted `.regular` over a true-black canvas lifts to `#363438` —
        //   a pale grey slab that stops reading as this app's chrome, and the
        //   `textSecondary` unselected labels measured **3.81:1** against it,
        //   under the spec's 4.5:1 floor.
        // - the solid token as a tint renders `#16161A` exactly: the flat bar
        //   again, with none of the material left.
        //
        // 60% is where it settles. At 50% the bar sampled `#262529` for
        // **4.72:1**, but that is the contrast over *black*; where a card or a
        // line of copy passes under the capsule the material lifts with it, and
        // on Settings the patch behind the "Scan" label rose to `#2B2A2E`,
        // dragging that label to **4.36:1**. The extra 10% both darkens the
        // resting bar and damps how far the content underneath can push it: the
        // same two patches now sample `#212125` over black (**4.97:1**) and
        // `#27262B` under that line of copy (**4.65:1**), so the floor holds
        // with something scrolling past rather than only on an empty stretch of
        // canvas. Enough material survives to keep the specular rim and the
        // visible lensing — which is the whole point of putting glass here
        // rather than anywhere else.
        .ocrGlass(
            .capsule,
            tint: Theme.tabBarFill.opacity(0.6),
            fallback: Theme.tabBarFill,
            reduceTransparency: reduceTransparency
        )
        .shadow(color: .black.opacity(0.6), radius: 15, y: 10)
        .padding(.horizontal, 14)
        .padding(.bottom, 30)
        // The design measures the 30pt inset from the bottom of the *screen*,
        // not from the home-indicator safe area. Without this the bar floated
        // 64 up instead of 30 and the whole layout read short.
        .ignoresSafeArea(.container, edges: .bottom)
    }
}
