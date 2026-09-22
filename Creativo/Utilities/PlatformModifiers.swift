import SwiftUI

/// Cross-platform wrappers around modifiers that only exist on one platform.
///
/// Keeping the `#if` here means feature code never has to branch on the OS,
/// which is what stops the Mac build from slowly turning into a big iPad.
extension View {
    /// Compact navigation title on iPadOS, unchanged on macOS where the title
    /// lives in the window chrome.
    func inlineNavigationTitle() -> some View {
        #if os(iOS)
        return navigationBarTitleDisplayMode(.inline)
        #else
        return self
        #endif
    }

    /// Gives a sheet a sensible window size on macOS and leaves iPadOS to its
    /// own presentation rules.
    func macSheetFrame(
        minWidth: CGFloat = 560,
        minHeight: CGFloat = 520,
        idealWidth: CGFloat = 640,
        idealHeight: CGFloat = 600
    ) -> some View {
        #if os(macOS)
        return frame(
            minWidth: minWidth,
            idealWidth: idealWidth,
            minHeight: minHeight,
            idealHeight: idealHeight
        )
        #else
        return self
        #endif
    }

    /// The grouped form look, which reads correctly on both platforms.
    func creativoFormStyle() -> some View {
        formStyle(.grouped)
    }
}

extension View {
    /// Numeric keypad on iPadOS, no-op on macOS.
    func numericKeyboard() -> some View {
        #if os(iOS)
        return keyboardType(.numberPad)
        #else
        return self
        #endif
    }

    /// Decimal keypad on iPadOS, no-op on macOS.
    func decimalKeyboard() -> some View {
        #if os(iOS)
        return keyboardType(.decimalPad)
        #else
        return self
        #endif
    }

    /// Disables autocorrection and capitalisation for identifier-like fields.
    func rawTextField() -> some View {
        #if os(iOS)
        return autocorrectionDisabled().textInputAutocapitalization(.never)
        #else
        return autocorrectionDisabled()
        #endif
    }
}
