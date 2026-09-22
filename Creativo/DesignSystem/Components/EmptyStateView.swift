import SwiftUI

/// The app's one and only empty state.
///
/// Every screen that has nothing to show uses this, including the sections that
/// are not built yet: an unbuilt section still explains what it will do and
/// offers the action that will create the first item.
struct EmptyStateView<Actions: View>: View {
    let symbolName: String
    let title: String
    let message: String
    var tint: Color = .accentColor
    @ViewBuilder var actions: Actions

    init(
        symbolName: String,
        title: String,
        message: String,
        tint: Color = .accentColor,
        @ViewBuilder actions: () -> Actions
    ) {
        self.symbolName = symbolName
        self.title = title
        self.message = message
        self.tint = tint
        self.actions = actions()
    }

    var body: some View {
        VStack(spacing: Spacing.lg) {
            Image(systemName: symbolName)
                .font(.system(size: 42, weight: .light))
                .foregroundStyle(tint.gradient)
                .symbolRenderingMode(.hierarchical)
                .padding(Spacing.xl)
                .background(tint.opacity(0.10), in: Circle())

            VStack(spacing: Spacing.sm) {
                Text(title)
                    .font(.title3.weight(.semibold))
                    .multilineTextAlignment(.center)
                Text(message)
                    .font(.callout)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
                    .frame(maxWidth: 420)
            }

            actions
        }
        .padding(Spacing.xxl)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}

extension EmptyStateView where Actions == EmptyView {
    init(symbolName: String, title: String, message: String, tint: Color = .accentColor) {
        self.init(symbolName: symbolName, title: title, message: message, tint: tint) {
            EmptyView()
        }
    }
}

#Preview("Avec action") {
    EmptyStateView(
        symbolName: "rectangle.3.group",
        title: "Board",
        message: "Construisez l'univers visuel de votre projet.",
        tint: .purple
    ) {
        Button("Créer le premier board") {}
            .buttonStyle(.borderedProminent)
    }
}

#Preview("Sans action") {
    EmptyStateView(
        symbolName: "tray",
        title: "Rien ici",
        message: "Les éléments que vous ajouterez apparaîtront à cet endroit."
    )
}
