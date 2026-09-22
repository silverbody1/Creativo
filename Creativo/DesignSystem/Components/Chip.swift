import SwiftUI

/// Compact tinted label used for statuses, categories and attributes.
struct Chip: View {
    let text: String
    var symbolName: String?
    var tint: Color = .secondary
    var style: Style = .tinted

    enum Style {
        /// Coloured text on a soft tinted background.
        case tinted
        /// Neutral text on a grey background, for secondary metadata.
        case neutral
        /// Text only, for the densest rows.
        case plain
    }

    var body: some View {
        HStack(spacing: Spacing.xs) {
            if let symbolName {
                Image(systemName: symbolName)
                    .font(.caption2.weight(.semibold))
            }
            Text(text)
                .font(.caption.weight(.medium))
                .lineLimit(1)
        }
        .foregroundStyle(foreground)
        .padding(.horizontal, style == .plain ? 0 : Spacing.sm)
        .padding(.vertical, style == .plain ? 0 : Spacing.xs)
        .background(background, in: Capsule(style: .continuous))
    }

    private var foreground: Color {
        switch style {
        case .tinted: return tint
        case .neutral, .plain: return .secondary
        }
    }

    private var background: Color {
        switch style {
        case .tinted: return tint.opacity(0.14)
        case .neutral: return Surface.badge
        case .plain: return .clear
        }
    }
}

/// A status dot followed by its label, for list rows where a chip is too heavy.
struct StatusDot: View {
    let text: String
    let tint: Color

    var body: some View {
        HStack(spacing: Spacing.xs) {
            Circle()
                .fill(tint)
                .frame(width: 7, height: 7)
            Text(text)
                .font(.caption)
                .foregroundStyle(.secondary)
                .lineLimit(1)
        }
    }
}

#Preview {
    VStack(alignment: .leading, spacing: Spacing.md) {
        HStack {
            Chip(text: "Préproduction", symbolName: "list.bullet.clipboard", tint: .teal)
            Chip(text: "Clip musical", symbolName: "music.note.tv", tint: .purple)
            Chip(text: "INT. NUIT", style: .neutral)
        }
        StatusDot(text: "Tourné", tint: .green)
    }
    .padding()
}
