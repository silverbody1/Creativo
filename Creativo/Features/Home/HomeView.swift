import SwiftUI
import SwiftData

/// Landing screen: greeting, the project to resume, then recent and favourite projects.
struct HomeView: View {
    @Environment(AppState.self) private var appState
    @Environment(\.modelContext) private var modelContext
    @Query(sort: \Project.updatedAt, order: .reverse) private var projects: [Project]

    private var activeProjects: [Project] {
        projects.filter { $0.status != .archived }
    }

    private var recentProjects: [Project] {
        Array(activeProjects.prefix(6))
    }

    private var favoriteProjects: [Project] {
        projects.filter(\.isFavorite)
    }

    var body: some View {
        ScrollView {
            LazyVStack(alignment: .leading, spacing: Spacing.xxl) {
                greeting

                if projects.isEmpty {
                    emptyState
                } else {
                    if let latest = activeProjects.first {
                        resumeSection(latest)
                    }
                    recentSection
                    if !favoriteProjects.isEmpty {
                        favoritesSection
                    }
                }
            }
            .padding(Spacing.xl)
            .readableContentWidth()
        }
        .navigationTitle("Accueil")
        .inlineNavigationTitle()
        .toolbar {
            ToolbarItem(placement: .primaryAction) {
                Button {
                    appState.presentNewProject()
                } label: {
                    Label("Nouveau projet", systemImage: "plus")
                }
                .help("Créer un projet (⌘N)")
            }
        }
    }

    // MARK: Sections

    private var greeting: some View {
        VStack(alignment: .leading, spacing: Spacing.xs) {
            Text(Self.greetingText())
                .font(.system(.largeTitle, design: .rounded, weight: .semibold))
            Text(subtitle)
                .font(.title3)
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private var subtitle: String {
        switch activeProjects.count {
        case 0: return "Prêt à lancer votre premier projet ?"
        case 1: return "Un projet en cours."
        default: return "\(activeProjects.count) projets en cours."
        }
    }

    private func resumeSection(_ project: Project) -> some View {
        VStack(alignment: .leading, spacing: Spacing.md) {
            SectionHeaderView("Reprendre")
            Button {
                appState.open(project)
            } label: {
                HStack(spacing: Spacing.lg) {
                    ProjectCoverView(project: project)
                        .frame(width: 148)

                    VStack(alignment: .leading, spacing: Spacing.sm) {
                        Text(project.displayName)
                            .font(.title3.weight(.semibold))
                            .lineLimit(1)
                        HStack(spacing: Spacing.sm) {
                            Chip(
                                text: project.type.displayName,
                                symbolName: project.type.symbolName,
                                tint: project.type.tint
                            )
                            Chip(text: project.status.displayName, tint: project.status.tint)
                        }
                        Text(progressSummary(for: project))
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }

                    Spacer(minLength: Spacing.sm)

                    Image(systemName: "chevron.right")
                        .font(.body.weight(.semibold))
                        .foregroundStyle(.tertiary)
                }
                .cardSurface()
            }
            .buttonStyle(.plain)
        }
    }

    private func progressSummary(for project: Project) -> String {
        let scenes = AppFormat.count(project.scenes.count, singular: "scène", plural: "scènes", zero: "Aucune scène")
        let progress = project.shotProgress
        guard progress.total > 0 else { return "\(scenes) · aucun plan" }
        return "\(scenes) · \(progress.completed)/\(progress.total) plans tournés"
    }

    private var recentSection: some View {
        VStack(alignment: .leading, spacing: Spacing.md) {
            SectionHeaderView("Projets récents") {
                Button("Tout voir") {
                    appState.sidebarSelection = .allProjects
                }
                .buttonStyle(.borderless)
                .font(.callout)
            }
            projectGrid(recentProjects)
        }
    }

    private var favoritesSection: some View {
        VStack(alignment: .leading, spacing: Spacing.md) {
            SectionHeaderView("Favoris")
            projectGrid(favoriteProjects)
        }
    }

    private func projectGrid(_ items: [Project]) -> some View {
        LazyVGrid(
            columns: [
                GridItem(
                    .adaptive(minimum: LayoutMetrics.projectCardMinWidth),
                    spacing: Spacing.lg
                )
            ],
            spacing: Spacing.lg
        ) {
            ForEach(items) { project in
                ProjectCard(
                    project: project,
                    onOpen: { appState.open(project) },
                    onToggleFavorite: {
                        ProjectService.toggleFavorite(project, in: modelContext)
                    }
                )
            }
        }
    }

    private var emptyState: some View {
        EmptyStateView(
            symbolName: "film.stack",
            title: "Aucun projet pour le moment",
            message: "Créez votre premier projet pour commencer à écrire, découper et préparer votre tournage."
        ) {
            Button {
                appState.presentNewProject()
            } label: {
                Label("Nouveau projet", systemImage: "plus")
                    .touchTarget()
                    .padding(.horizontal, Spacing.sm)
            }
            .buttonStyle(.borderedProminent)
            .controlSize(.large)
        }
        .frame(minHeight: 340)
    }

    // MARK: Helpers

    /// Greeting derived from the time of day; deterministic, no randomness.
    static func greetingText(now: Date = .now, calendar: Calendar = .current) -> String {
        let hour = calendar.component(.hour, from: now)
        switch hour {
        case 5..<12: return "Bonjour"
        case 12..<18: return "Bon après-midi"
        default: return "Bonsoir"
        }
    }
}

#Preview("Avec projets") {
    NavigationStack {
        HomeView()
    }
    .environment(AppState())
    .modelContainer(SampleData.previewContainer)
}

#Preview("Vide") {
    NavigationStack {
        HomeView()
    }
    .environment(AppState())
    .modelContainer(SampleData.emptyPreviewContainer)
}
