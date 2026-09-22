import SwiftUI

/// One line of a shot list.
struct ShotRow: View {
    let shot: Shot
    var onToggleStatus: (() -> Void)?

    var body: some View {
        HStack(spacing: Spacing.md) {
            Text(shot.displayNumber)
                .font(.caption.monospacedDigit().weight(.semibold))
                .foregroundStyle(.secondary)
                .frame(minWidth: 38, minHeight: 30)
                .background(Surface.badge, in: RoundedRectangle(cornerRadius: CornerRadius.small, style: .continuous))

            VStack(alignment: .leading, spacing: Spacing.xxs) {
                Text(shot.displayTitle)
                    .font(.body.weight(.medium))
                    .lineLimit(1)
                Text(shot.technicalSummary)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
            }

            Spacer(minLength: Spacing.sm)

            Chip(text: shot.shotSize.abbreviation, style: .neutral)

            if let onToggleStatus {
                Button(action: onToggleStatus) {
                    Image(systemName: shot.status.symbolName)
                        .font(.body)
                        .foregroundStyle(shot.status.tint)
                        .frame(width: 32, height: 32)
                        .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
                .help("Statut : \(shot.status.displayName)")
                .accessibilityLabel("Statut du plan, \(shot.status.displayName)")
            } else {
                Image(systemName: shot.status.symbolName)
                    .foregroundStyle(shot.status.tint)
            }
        }
        .touchTarget()
    }
}

#Preview {
    List {
        ShotRow(shot: Shot(shotNumber: "1A", title: "Plongée ville", shotSize: .extremeWide, cameraMovement: .drone, lens: "24 mm"))
        ShotRow(shot: Shot(shotNumber: "1B", title: "Regard caméra", shotSize: .closeUp, cameraMovement: .fixed, lens: "85 mm", status: .shot), onToggleStatus: {})
    }
}
