import SwiftUI

/// Minutes and seconds entry, bound to a `TimeInterval` in seconds.
struct DurationField: View {
    @Binding var duration: TimeInterval

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
            TextField("0", value: minutes, format: .number)
                .frame(width: 54)
                .multilineTextAlignment(.trailing)
                .numericKeyboard()
            Text("min")
                .foregroundStyle(.secondary)

            TextField("0", value: seconds, format: .number)
                .frame(width: 54)
                .multilineTextAlignment(.trailing)
                .numericKeyboard()
            Text("s")
                .foregroundStyle(.secondary)

            Spacer(minLength: 0)

            Text(AppFormat.timecode(duration))
                .font(.callout.monospacedDigit())
                .foregroundStyle(.tertiary)
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
