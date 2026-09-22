import SwiftUI

/// One line of the equipment library.
struct EquipmentRow: View {
    let item: EquipmentItem
    var trailingText: String?

    var body: some View {
        HStack(spacing: Spacing.md) {
            IconTile(symbolName: item.category.symbolName, tint: item.category.tint)

            VStack(alignment: .leading, spacing: Spacing.xxs) {
                Text(item.displayName)
                    .font(.body.weight(.medium))
                    .lineLimit(1)
                HStack(spacing: Spacing.xs) {
                    Text(item.category.displayName)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    if !item.makeAndModel.isBlank {
                        Text("· \(item.makeAndModel)")
                            .font(.caption)
                            .foregroundStyle(.tertiary)
                            .lineLimit(1)
                    }
                }
            }

            Spacer(minLength: Spacing.sm)

            if item.owned {
                Chip(text: "Possédé", tint: .green)
            }

            if let trailingText {
                Text(trailingText)
                    .font(.caption.monospacedDigit())
                    .foregroundStyle(.secondary)
            } else if let rate = item.defaultDailyRate {
                Text("\(AppFormat.currency(rate))/j")
                    .font(.caption.monospacedDigit())
                    .foregroundStyle(.secondary)
            }
        }
        .touchTarget()
    }
}

#Preview {
    List {
        EquipmentRow(item: EquipmentItem(name: "FX3", category: .camera, brand: "Sony", model: "ILME-FX3", owned: true))
        EquipmentRow(item: EquipmentItem(name: "Aputure 600d", category: .lighting, brand: "Aputure", defaultDailyRate: 60))
    }
}
