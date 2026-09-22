import SwiftUI

/// A single figure with its label, used by the project dashboard.
struct StatCard: View {
    let title: String
    let value: String
    var caption: String?
    var symbolName: String
    var tint: Color = .accentColor
    /// Optional 0...1 completion ratio rendered as a thin bar under the value.
    var progress: Double?

    var body: some View {
        VStack(alignment: .leading, spacing: Spacing.md) {
            HStack(spacing: Spacing.sm) {
                Image(systemName: symbolName)
                    .font(.footnote.weight(.semibold))
                    .foregroundStyle(tint)
                Text(title.uppercased())
                    .font(.caption2.weight(.semibold))
                    .tracking(0.6)
                    .foregroundStyle(.secondary)
                Spacer(minLength: 0)
            }

            VStack(alignment: .leading, spacing: Spacing.xs) {
                Text(value)
                    .font(.system(.title2, design: .rounded, weight: .semibold))
                    .monospacedDigit()
                    .lineLimit(1)
                    .minimumScaleFactor(0.6)
                    .contentTransition(.numericText())

                if let caption {
                    Text(caption)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .lineLimit(2)
                }
            }

            if let progress {
                ProgressView(value: min(max(progress, 0), 1))
                    .progressViewStyle(.linear)
                    .tint(tint)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .cardSurface()
    }
}

#Preview {
    LazyVGrid(
        columns: [GridItem(.adaptive(minimum: LayoutMetrics.statCardMinWidth), spacing: Spacing.md)],
        spacing: Spacing.md
    ) {
        StatCard(title: "Scènes", value: "12", caption: "3 verrouillées", symbolName: "list.bullet.rectangle", tint: .blue)
        StatCard(title: "Plans", value: "48", caption: "18 tournés", symbolName: "camera.viewfinder", tint: .teal, progress: 0.375)
        StatCard(title: "Budget", value: "8 400 €", caption: "sur 10 000 €", symbolName: "eurosign.circle", tint: .green, progress: 0.84)
    }
    .padding()
}
