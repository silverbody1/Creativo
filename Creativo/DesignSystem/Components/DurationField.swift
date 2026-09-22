import SwiftUI

/// Minutes and seconds entry, bound to a `TimeInterval` in seconds.
struct DurationField: View {
    @Binding var duration: TimeInterval
    /// Optional focus flag shared with the host screen. A timeline that binds
    /// the space bar and the arrow keys needs to know when the keyboard
    /// belongs to a text field instead.
    var focus: FocusState<Bool>.Binding?

    private var minutes: Binding<Int> {
        Binding(
            get: { Int(max(duration, 0)) / 60 },
            set: { newValue in
                let seconds = Int(max(duration, 0)) % 60
                duration = TimeInterval(max(newValue, 0) * 60 + seconds)
            }
        )
    }

    private var seconds: Binding<Int> {
        Binding(
            get: { Int(max(duration, 0)) % 60 },
            set: { newValue in
                let clamped = min(max(newValue, 0), 59)
                let mins = Int(max(duration, 0)) / 60
                duration = TimeInterval(mins * 60 + clamped)
            }
        )
    }

    var body: some View {
        HStack(spacing: Spacing.sm) {
            focusable(
                TextField("0", value: minutes, format: .number)
                    .frame(width: 54)
                    .multilineTextAlignment(.trailing)
                    .numericKeyboard()
            )
            Text("min")
                .foregroundStyle(.secondary)

            focusable(
                TextField("0", value: seconds, format: .number)
                    .frame(width: 54)
                    .multilineTextAlignment(.trailing)
                    .numericKeyboard()
            )
            Text("s")
                .foregroundStyle(.secondary)

            Spacer(minLength: 0)

            Text(AppFormat.timecode(duration))
                .font(.callout.monospacedDigit())
                .foregroundStyle(.tertiary)
        }
    }

    @ViewBuilder
    private func focusable(_ field: some View) -> some View {
        if let focus {
            field.focused(focus)
        } else {
            field
        }
    }
}

private struct DurationFieldPreview: View {
    @State private var duration: TimeInterval = 95

    var body: some View {
        Form {
            DurationField(duration: $duration)
        }
    }
}

#Preview {
    DurationFieldPreview()
}
