import SwiftUI

// MARK: - Spacing

/// The only spacing values the app is allowed to use.
///
/// A short scale on purpose: every screen built from the same six steps reads
/// as one product, and there is no temptation to hand-tune a 13 pt gap.
enum Spacing {
    static let xxs: CGFloat = 2
    static let xs: CGFloat = 4
    static let sm: CGFloat = 8
    static let md: CGFloat = 12
    static let lg: CGFloat = 16
    static let xl: CGFloat = 24
    static let xxl: CGFloat = 32
    static let xxxl: CGFloat = 48
}

// MARK: - Corner radius

/// Corner radii, always used with `.continuous` so shapes match Apple's own.
enum CornerRadius {
    static let small: CGFloat = 8
    static let medium: CGFloat = 12
    static let large: CGFloat = 16
    static let extraLarge: CGFloat = 22
    static let pill: CGFloat = 999
}

// MARK: - Layout

/// Fixed layout measurements shared across platforms.
enum LayoutMetrics {
    static let sidebarMinWidth: CGFloat = 212
    static let sidebarIdealWidth: CGFloat = 252
    static let sidebarMaxWidth: CGFloat = 320

    /// Width under which a screen switches to its compact arrangement. Read
    /// from the real container width rather than a size class, because
    /// `horizontalSizeClass` does not exist on macOS.
    static let compactWidthThreshold: CGFloat = 720

    /// Reading width cap, so text never stretches across a 32" display.
    static let contentMaxWidth: CGFloat = 1180
    static let formMaxWidth: CGFloat = 640

    /// Minimum width of a project card in the adaptive grid.
    static let projectCardMinWidth: CGFloat = 268
    static let statCardMinWidth: CGFloat = 156

    /// Apple's minimum comfortable touch target, honoured on iPad.
    static let minimumTouchTarget: CGFloat = 44

    static let coverAspectRatio: CGFloat = 16.0 / 9.0
    static let avatarSize: CGFloat = 34
}

// MARK: - Surfaces

/// Surface tints expressed as a fraction of `Color.primary`.
///
/// Deriving every surface from the semantic primary colour is what guarantees
/// Dark Mode support: there is no hard-coded RGB anywhere to invert.
enum Surface {
    static let card = Color.primary.opacity(0.05)
    static let cardElevated = Color.primary.opacity(0.08)
    static let subtle = Color.primary.opacity(0.03)
    static let separator = Color.primary.opacity(0.08)
    static let badge = Color.primary.opacity(0.07)
}

// MARK: - View helpers

extension View {
    /// Standard card treatment: padding, soft fill, continuous corners, no border.
    func cardSurface(
        radius: CGFloat = CornerRadius.large,
        padding: CGFloat = Spacing.lg,
        fill: Color = Surface.card
    ) -> some View {
        self
            .padding(padding)
            .background(fill, in: RoundedRectangle(cornerRadius: radius, style: .continuous))
    }

    /// Caps the reading width and keeps the block centred on wide displays.
    func readableContentWidth(_ maxWidth: CGFloat = LayoutMetrics.contentMaxWidth) -> some View {
        frame(maxWidth: maxWidth, alignment: .leading)
            .frame(maxWidth: .infinity, alignment: .leading)
    }

    /// Guarantees a comfortable tap target without changing the visual size.
    func touchTarget(_ minimum: CGFloat = LayoutMetrics.minimumTouchTarget) -> some View {
        frame(minHeight: minimum)
            .contentShape(Rectangle())
    }
}
