import SwiftUI

/// Circular avatar showing someone's initials, tinted by their department.
struct InitialsAvatar: View {
    let initials: String
    var tint: Color = .accentColor
    var size: CGFloat = LayoutMetrics.avatarSize

    var body: some View {
        Text(initials)
            .font(.system(size: size * 0.38, weight: .semibold, design: .rounded))
            .foregroundStyle(tint)
            .frame(width: size, height: size)
            .background(tint.opacity(0.16), in: Circle())
            .accessibilityHidden(true)
    }
}

/// Square rounded tile holding an SF Symbol, used as a list row leading icon.
struct IconTile: View {
    let symbolName: String
    var tint: Color = .accentColor
    var size: CGFloat = LayoutMetrics.avatarSize

    var body: some View {
        Image(systemName: symbolName)
            .font(.system(size: size * 0.42, weight: .medium))
            .foregroundStyle(tint)
            .frame(width: size, height: size)
            .background(
                tint.opacity(0.14),
                in: RoundedRectangle(cornerRadius: size * 0.28, style: .continuous)
            )
            .accessibilityHidden(true)
    }
}

#Preview {
    HStack(spacing: Spacing.md) {
        InitialsAvatar(initials: "LM", tint: .indigo)
        InitialsAvatar(initials: "AD", tint: .orange, size: 48)
        IconTile(symbolName: "camera", tint: .teal)
        IconTile(symbolName: "mappin.and.ellipse", tint: .pink, size: 48)
    }
    .padding()
}
