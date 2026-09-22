import SwiftUI

/// Dense project row, used by the list layout of the project screen.
struct ProjectRow: View {
    let project: Project

    var body: some View {
        HStack(spacing: Spacing.md) {
            IconTile(symbolName: project.type.symbolName, tint: project.type.tint, size: 38)

            VStack(alignment: .leading, spacing: Spacing.xxs) {
                Text(project.displayName)
                    .font(.body.weight(.medium))
                    .lineLimit(1)
                HStack(spacing: Spacing.sm) {
                    StatusDot(text: project.status.displayName, tint: project.status.tint)
                    Text("·")
                        .foregroundStyle(.tertiary)
                    Text(AppFormat.relative(project.updatedAt))
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }

            Spacer(minLength: Spacing.sm)

            if project.isFavorite {
                Image(systemName: "star.fill")
                    .font(.caption)
                    .foregroundStyle(.yellow)
            }

            Text(project.type.displayName)
                .font(.caption)
                .foregroundStyle(.secondary)
                .lineLimit(1)
        }
        .touchTarget()
    }
}

#Preview {
    List {
        ProjectRow(project: Project(name: "PARTENAIRE", type: .musicVideo, status: .preProduction, isFavorite: true))
        ProjectRow(project: Project(name: "Court-métrage", type: .film, status: .writing))
    }
}
