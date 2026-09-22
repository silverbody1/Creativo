import SwiftUI

/// Small uppercase heading used above every block of content.
struct SectionHeaderView<Trailing: View>: View {
    let title: String
    var subtitle: String?
    @ViewBuilder var trailing: Trailing

    init(_ title: String, subtitle: String? = nil, @ViewBuilder trailing: () -> Trailing) {
        self.title = title
        self.subtitle = subtitle
        self.trailing = trailing()
    }

    var body: some View {
        HStack(alignment: .firstTextBaseline, spacing: Spacing.md) {
            VStack(alignment: .leading, spacing: Spacing.xxs) {
                Text(title.uppercased())
                    .font(.caption.weight(.semibold))
                    .tracking(0.8)
                    .foregroundStyle(.secondary)
                if let subtitle {
                    Text(subtitle)
                        .font(.footnote)
                        .foregroundStyle(.tertiary)
                }
            }
            Spacer(minLength: Spacing.sm)
            trailing
        }
    }
}

extension SectionHeaderView where Trailing == EmptyView {
    init(_ title: String, subtitle: String? = nil) {
        self.init(title, subtitle: subtitle) { EmptyView() }
    }
}

#Preview {
    VStack(alignment: .leading, spacing: Spacing.xl) {
        SectionHeaderView("Projets récents")
        SectionHeaderView("Budget", subtitle: "12 lignes") {
            Button("Ajouter") {}
                .buttonStyle(.bordered)
        }
    }
    .padding()
}
