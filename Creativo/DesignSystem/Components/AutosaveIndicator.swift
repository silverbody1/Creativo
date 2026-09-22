import SwiftUI

/// Quiet confirmation that the work is on disk.
///
/// Editors save continuously, which is only reassuring if the interface says
/// so. It shows the moment of the last change rather than a spinner, because
/// that is the question a writer actually asks.
struct AutosaveIndicator: View {
    let date: Date
    var label: String = "Enregistré"

    var body: some View {
        HStack(spacing: Spacing.xs) {
            Image(systemName: "checkmark.circle")
                .font(.caption2)
            Text("\(label) \(AppFormat.relative(date))")
                .font(.caption)
                .lineLimit(1)
        }
        .foregroundStyle(.tertiary)
        .accessibilityLabel("\(label) \(AppFormat.relative(date))")
    }
}

#Preview {
    VStack(alignment: .leading, spacing: Spacing.md) {
        AutosaveIndicator(date: .now)
        AutosaveIndicator(date: .now.addingTimeInterval(-3_600))
    }
    .padding()
}
