import SwiftUI

/// Selectable card describing one kind of project.
struct ProjectTypeCard: View {
    let type: ProjectType
    var isSelected: Bool = false
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            VStack(alignment: .leading, spacing: Spacing.md) {
                Image(systemName: type.symbolName)
                    .font(.system(size: 24, weight: .regular))
                    .foregroundStyle(type.tint)
                    .frame(width: 46, height: 46)
                    .background(type.tint.opacity(0.14), in: RoundedRectangle(cornerRadius: CornerRadius.medium, style: .continuous))

                VStack(alignment: .leading, spacing: Spacing.xxs) {
                    Text(type.displayName)
                        .font(.headline)
                        .foregroundStyle(.primary)
                        .multilineTextAlignment(.leading)
                    Text(type.shortDescription)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .multilineTextAlignment(.leading)
                        .fixedSize(horizontal: false, vertical: true)
                }
            }
            .frame(maxWidth: .infinity, minHeight: 150, alignment: .topLeading)
            .padding(Spacing.lg)
            .background(
                isSelected ? type.tint.opacity(0.12) : Surface.card,
                in: RoundedRectangle(cornerRadius: CornerRadius.large, style: .continuous)
            )
            .overlay {
                RoundedRectangle(cornerRadius: CornerRadius.large, style: .continuous)
                    .strokeBorder(isSelected ? type.tint : Color.clear, lineWidth: 2)
            }
        }
        .buttonStyle(.plain)
        .accessibilityLabel(type.displayName)
        .accessibilityHint(type.shortDescription)
        .accessibilityAddTraits(isSelected ? [.isButton, .isSelected] : .isButton)
    }
}

#Preview {
    LazyVGrid(columns: [GridItem(.adaptive(minimum: 220), spacing: Spacing.md)], spacing: Spacing.md) {
        ForEach(ProjectType.allCases) { type in
            ProjectTypeCard(type: type, isSelected: type == .musicVideo) {}
        }
    }
    .padding()
}
