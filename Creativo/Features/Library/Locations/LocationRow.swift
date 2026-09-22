import SwiftUI

/// One line of the locations library.
struct LocationRow: View {
    let location: ProductionLocation
    var trailingText: String?

    var body: some View {
        HStack(spacing: Spacing.md) {
            IconTile(symbolName: "mappin.and.ellipse", tint: .pink)

            VStack(alignment: .leading, spacing: Spacing.xxs) {
                Text(location.displayName)
                    .font(.body.weight(.medium))
                    .lineLimit(1)
                if !location.address.isBlank {
                    Text(location.address)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                }
                if !location.amenities.isEmpty {
                    HStack(spacing: Spacing.xs) {
                        ForEach(location.amenities) { amenity in
                            Image(systemName: amenity.symbolName)
                                .font(.caption2)
                                .foregroundStyle(.tertiary)
                                .help(amenity.displayName)
                        }
                    }
                }
            }

            Spacer(minLength: Spacing.sm)

            if let trailingText {
                Text(trailingText)
                    .font(.caption.monospacedDigit())
                    .foregroundStyle(.secondary)
            } else if let price = location.pricePerDay {
                Text("\(AppFormat.currency(price))/j")
                    .font(.caption.monospacedDigit())
                    .foregroundStyle(.secondary)
            }
        }
        .touchTarget()
    }
}

#Preview {
    List {
        LocationRow(location: ProductionLocation(name: "Studio Est", address: "12 rue des Lilas, Paris", pricePerDay: 450, powerAvailable: true, indoorAvailable: true))
    }
}
