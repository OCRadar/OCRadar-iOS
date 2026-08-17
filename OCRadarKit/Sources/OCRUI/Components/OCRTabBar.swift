import SwiftUI

/// The floating capsule tab bar that replaces the system one. Screens extend
/// under it, so it is overlaid on a bottom-aligned `ZStack` by `RootView`
/// rather than reserving a safe-area inset.
///
/// It owns its own 14pt horizontal inset and 30pt bottom offset, so callers add
/// no padding around it. Screens clear it with `Theme.tabBarClearance`.
struct OCRTabBar: View {
    @Binding var selection: AppTab

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
                    .background(isSelected ? Theme.surfaceRaised : .clear, in: .capsule)
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
        .background(Theme.tabBarFill, in: .capsule)
        .shadow(color: .black.opacity(0.6), radius: 15, y: 10)
        .padding(.horizontal, 14)
        .padding(.bottom, 30)
        // The design measures the 30pt inset from the bottom of the *screen*,
        // not from the home-indicator safe area. Without this the bar floated
        // 64 up instead of 30 and the whole layout read short.
        .ignoresSafeArea(.container, edges: .bottom)
    }
}
