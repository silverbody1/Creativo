import SwiftUI

/// How each screenplay element is laid out on the page.
///
/// Lives in the design system, not in the model: indents and casing are
/// typography, and the domain has no opinion on them. The numbers follow
/// standard screenplay margins, scaled down when the column is narrow so an
/// iPad in portrait or in Split View stays readable.
enum ScreenplayStyle {
    /// Width of the page column. Beyond this the text would stop reading like
    /// a screenplay and start reading like a web page.
    static let pageWidth: CGFloat = 660

    /// The monospaced face gives the format its familiar rhythm without
    /// dragging Courier into a modern Apple interface.
    static func font(for type: ScreenplayElementType) -> Font {
        switch type {
        case .character, .transition:
            return .system(.body, design: .monospaced, weight: .semibold)
        case .note:
            return .system(.callout, design: .rounded)
        default:
            return .system(.body, design: .monospaced)
        }
    }

    static func alignment(for type: ScreenplayElementType) -> HorizontalAlignment {
        type == .transition ? .trailing : .leading
    }

    static func textAlignment(for type: ScreenplayElementType) -> TextAlignment {
        type == .transition ? .trailing : .leading
    }

    /// Left and right indents, in points, for a full-width page column.
    static func insets(for type: ScreenplayElementType, compact: Bool) -> EdgeInsets {
        let scale: CGFloat = compact ? 0.45 : 1
        switch type {
        case .action:
            return EdgeInsets(top: 0, leading: 0, bottom: 0, trailing: 0)
        case .character:
            return EdgeInsets(top: 0, leading: 190 * scale, bottom: 0, trailing: 0)
        case .dialogue:
            return EdgeInsets(top: 0, leading: 110 * scale, bottom: 0, trailing: 90 * scale)
        case .parenthetical:
            return EdgeInsets(top: 0, leading: 150 * scale, bottom: 0, trailing: 130 * scale)
        case .transition:
            return EdgeInsets(top: 0, leading: 0, bottom: 0, trailing: 0)
        case .note:
            return EdgeInsets(top: 0, leading: 0, bottom: 0, trailing: 0)
        }
    }

    /// Vertical breathing room before an element, following the format's rules.
    static func topSpacing(for type: ScreenplayElementType, previous: ScreenplayElementType?) -> CGFloat {
        guard let previous else { return Spacing.md }
        switch (previous, type) {
        case (.character, .dialogue), (.character, .parenthetical), (.parenthetical, .dialogue):
            return 0
        default:
            return Spacing.md
        }
    }

    static func tint(for type: ScreenplayElementType) -> Color {
        switch type {
        case .action: return .secondary
        case .character: return .indigo
        case .dialogue: return .primary
        case .parenthetical: return .teal
        case .transition: return .orange
        case .note: return .yellow
        }
    }

    /// Placeholder shown in an empty element, so the format teaches itself.
    static func placeholder(for type: ScreenplayElementType) -> String {
        switch type {
        case .action: return "Ce que l'on voit."
        case .character: return "PERSONNAGE"
        case .dialogue: return "Ce qu'il dit."
        case .parenthetical: return "à voix basse"
        case .transition: return "CUT TO:"
        case .note: return "Note de travail, jamais imprimée."
        }
    }
}
