import SwiftUI

/// The single card treatment used across the app: content padded onto Liquid
/// Glass with a continuous 24-point corner radius.
struct GlassCard<Content: View>: View {
    private let content: Content

    init(@ViewBuilder content: () -> Content) {
        self.content = content()
    }

    var body: some View {
        content
            .padding(Theme.cardPadding)
            .frame(maxWidth: .infinity, alignment: .leading)
            .glassEffect(.regular, in: .rect(cornerRadius: Theme.cornerRadius))
    }
}

#Preview {
    GlassCard {
        VStack(alignment: .leading, spacing: Theme.spacingS) {
            Text("Card Title")
                .font(.headline)
            Text("Supporting copy that wraps across multiple lines to show the padding and corner treatment.")
                .font(.subheadline)
                .foregroundStyle(.secondary)
        }
    }
    .padding()
}
