import SwiftUI

/// Bottom bar giving the focused line its type.
///
/// It exists so the format is reachable with a thumb on iPad, and it carries
/// ⌘1 through ⌘6 so it is never needed on a Mac.
struct ScreenplayElementBar: View {
    let currentType: ScreenplayElementType
    let onChangeType: (ScreenplayElementType) -> Void
    let onInsert: () -> Void
    let onDelete: () -> Void

    var body: some View {
        HStack(spacing: Spacing.sm) {
            ScrollView(.horizontal) {
                HStack(spacing: Spacing.xs) {
                    ForEach(ScreenplayElementType.allCases) { type in
                        Button {
                            onChangeType(type)
                        } label: {
                            Label(type.displayName, systemImage: type.symbolName)
                                .labelStyle(.titleAndIcon)
                                .font(.caption.weight(.medium))
                                .padding(.horizontal, Spacing.sm)
                                .touchTarget(36)
                        }
                        .buttonStyle(.plain)
                        .foregroundStyle(type == currentType ? Color.white : ScreenplayStyle.tint(for: type))
                        .background(
                            type == currentType
                                ? AnyShapeStyle(ScreenplayStyle.tint(for: type))
                                : AnyShapeStyle(ScreenplayStyle.tint(for: type).opacity(0.12)),
                            in: Capsule(style: .continuous)
                        )
                        .keyboardShortcut(KeyEquivalent(type.shortcutDigit), modifiers: .command)
                        .help("\(type.displayName) (⌘\(String(type.shortcutDigit)))")
                    }
                }
                .padding(.horizontal, Spacing.md)
            }
            .scrollIndicators(.hidden)

            Divider()
                .frame(height: 24)

            Button(action: onInsert) {
                Image(systemName: "return")
                    .frame(width: 32, height: 32)
                    .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .keyboardShortcut(.return, modifiers: .command)
            .help("Nouvelle ligne (⌘↩)")
            .accessibilityLabel("Nouvelle ligne")

            Button(role: .destructive, action: onDelete) {
                Image(systemName: "delete.left")
                    .frame(width: 32, height: 32)
                    .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .foregroundStyle(.red)
            .help("Supprimer la ligne")
            .accessibilityLabel("Supprimer la ligne")
            .padding(.trailing, Spacing.md)
        }
        .padding(.vertical, Spacing.sm)
        .background(.bar)
    }
}

#Preview {
    ScreenplayElementBar(
        currentType: .dialogue,
        onChangeType: { _ in },
        onInsert: {},
        onDelete: {}
    )
}
