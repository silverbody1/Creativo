import SwiftUI

/// Project tile used on the home screen and in the project grid.
struct ProjectCard: View {
    let project: Project
    var onOpen: () -> Void
    var onToggleFavorite: () -> Void

    var body: some View {
        Button(action: onOpen) {
            VStack(alignment: .leading, spacing: Spacing.md) {
                ProjectCoverView(project: project)
                    .overlay(alignment: .topTrailing) {
                        favoriteButton
                            .padding(Spacing.sm)
                    }

                VStack(alignment: .leading, spacing: Spacing.sm) {
                    Text(project.displayName)
                        .font(.headline)
                        .foregroundStyle(.primary)
                        .lineLimit(2)
                        .multilineTextAlignment(.leading)

                    HStack(spacing: Spacing.sm) {
                        Chip(
                            text: project.type.displayName,
                            symbolName: project.type.symbolName,
                            tint: project.type.tint
                        )
                        Chip(
                            text: project.status.displayName,
                            tint: project.status.tint
                        )
                    }

                    Text("Modifié \(AppFormat.relative(project.updatedAt))")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
            }
            .cardSurface(padding: Spacing.md)
        }
        .buttonStyle(.plain)
        .contentShape(Rectangle())
        .accessibilityElement(children: .combine)
        .accessibilityLabel("\(project.displayName), \(project.type.displayName), \(project.status.displayName)")
        .accessibilityAddTraits(.isButton)
    }

    private var favoriteButton: some View {
        Button(action: onToggleFavorite) {
            Image(systemName: project.isFavorite ? "star.fill" : "star")
                .font(.footnote.weight(.semibold))
                .foregroundStyle(project.isFavorite ? Color.yellow : Color.white.opacity(0.9))
                .padding(Spacing.sm)
                .background(Color.black.opacity(0.22), in: Circle())
        }
        .buttonStyle(.plain)
        .accessibilityLabel(project.isFavorite ? "Retirer des favoris" : "Ajouter aux favoris")
    }
}

#Preview {
    let project = Project(name: "PARTENAIRE", type: .musicVideo, status: .preProduction)
    LazyVGrid(
        columns: [GridItem(.adaptive(minimum: LayoutMetrics.projectCardMinWidth), spacing: Spacing.lg)],
        spacing: Spacing.lg
    ) {
        ProjectCard(project: project, onOpen: {}, onToggleFavorite: {})
        ProjectCard(
            project: Project(name: "Spot Nike", type: .commercial, status: .production),
            onOpen: {},
            onToggleFavorite: {}
        )
    }
    .padding()
}
