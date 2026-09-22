import SwiftUI
import SwiftData

enum ProjectsDisplayMode: String, CaseIterable, Identifiable {
    case grid
    case list

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .grid: return "Grille"
        case .list: return "Liste"
        }
    }

    var symbolName: String {
        switch self {
        case .grid: return "square.grid.2x2"
        case .list: return "list.bullet"
        }
    }
}

/// All projects, or only the favourites, with search and two display modes.
struct ProjectsListView: View {
    enum Scope {
        case all
        case favorites

        var title: String {
            switch self {
            case .all: return "Tous les projets"
            case .favorites: return "Favoris"
            }
        }
    }

    let scope: Scope

    @Environment(AppState.self) private var appState
    @Environment(\.modelContext) private var modelContext
    @Query(sort: \Project.updatedAt, order: .reverse) private var projects: [Project]

    @State private var query = ""
    @State private var projectPendingDeletion: Project?
    @AppStorage("projectsDisplayMode") private var displayMode: ProjectsDisplayMode = .grid

    private var scopedProjects: [Project] {
        switch scope {
        case .all: return projects
        case .favorites: return projects.filter(\.isFavorite)
        }
    }

    private var visibleProjects: [Project] {
        ProjectService.filter(scopedProjects, query: query)
    }

    var body: some View {
        Group {
            if scopedProjects.isEmpty {
                emptyState
            } else if visibleProjects.isEmpty {
                noResultsState
            } else if displayMode == .grid {
                gridLayout
            } else {
                listLayout
            }
        }
        .navigationTitle(scope.title)
        .inlineNavigationTitle()
        .searchable(text: $query, prompt: "Rechercher un projet")
        .toolbar {
            ToolbarItem(placement: .primaryAction) {
                Button {
                    appState.presentNewProject()
                } label: {
                    Label("Nouveau projet", systemImage: "plus")
                }
                .help("Créer un projet (⌘N)")
            }
            ToolbarItem(placement: .automatic) {
                Picker("Affichage", selection: $displayMode) {
                    ForEach(ProjectsDisplayMode.allCases) { mode in
                        Label(mode.displayName, systemImage: mode.symbolName)
                            .tag(mode)
                    }
                }
                .pickerStyle(.segmented)
                .labelsHidden()
            }
        }
        .confirmationDialog(
            "Supprimer ce projet ?",
            isPresented: deletionDialogBinding,
            presenting: projectPendingDeletion
        ) { project in
            Button("Supprimer définitivement", role: .destructive) {
                appState.closeIfOpened(project)
                ProjectService.delete(project, in: modelContext)
                projectPendingDeletion = nil
            }
            Button("Annuler", role: .cancel) {
                projectPendingDeletion = nil
            }
        } message: { project in
            Text("« \(project.displayName) », ses scènes, ses plans, son budget et son planning seront supprimés. Les personnes, lieux et matériels restent dans la bibliothèque.")
        }
    }

    private var deletionDialogBinding: Binding<Bool> {
        Binding(
            get: { projectPendingDeletion != nil },
            set: { isPresented in if !isPresented { projectPendingDeletion = nil } }
        )
    }

    // MARK: Layouts

    private var gridLayout: some View {
        ScrollView {
            LazyVGrid(
                columns: [
                    GridItem(
                        .adaptive(minimum: LayoutMetrics.projectCardMinWidth),
                        spacing: Spacing.lg
                    )
                ],
                spacing: Spacing.lg
            ) {
                ForEach(visibleProjects) { project in
                    ProjectCard(
                        project: project,
                        onOpen: { appState.open(project) },
                        onToggleFavorite: { ProjectService.toggleFavorite(project, in: modelContext) }
                    )
                    .contextMenu { contextMenu(for: project) }
                }
            }
            .padding(Spacing.xl)
            .readableContentWidth()
        }
    }

    private var listLayout: some View {
        List {
            ForEach(visibleProjects) { project in
                Button {
                    appState.open(project)
                } label: {
                    ProjectRow(project: project)
                }
                .buttonStyle(.plain)
                .contextMenu { contextMenu(for: project) }
                .swipeActions(edge: .trailing) {
                    Button(role: .destructive) {
                        projectPendingDeletion = project
                    } label: {
                        Label("Supprimer", systemImage: "trash")
                    }
                }
                .swipeActions(edge: .leading) {
                    Button {
                        ProjectService.toggleFavorite(project, in: modelContext)
                    } label: {
                        Label("Favori", systemImage: project.isFavorite ? "star.slash" : "star")
                    }
                    .tint(.yellow)
                }
            }
        }
    }

    @ViewBuilder
    private func contextMenu(for project: Project) -> some View {
        Button("Ouvrir") { appState.open(project) }
        Button(project.isFavorite ? "Retirer des favoris" : "Ajouter aux favoris") {
            ProjectService.toggleFavorite(project, in: modelContext)
        }
        Menu("Statut") {
            ForEach(ProjectStatus.allCases) { status in
                Button {
                    ProjectService.setStatus(status, on: project, in: modelContext)
                } label: {
                    Label(status.displayName, systemImage: status.symbolName)
                }
            }
        }
        Divider()
        Button("Supprimer…", role: .destructive) {
            projectPendingDeletion = project
        }
    }

    // MARK: States

    @ViewBuilder
    private var emptyState: some View {
        switch scope {
        case .all:
            EmptyStateView(
                symbolName: "film.stack",
                title: "Aucun projet",
                message: "Vos clips, films et vidéos apparaîtront ici."
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
        case .favorites:
            EmptyStateView(
                symbolName: "star",
                title: "Aucun favori",
                message: "Marquez un projet d'une étoile pour le retrouver instantanément ici.",
                tint: .yellow
            ) {
                Button("Voir tous les projets") {
                    appState.sidebarSelection = .allProjects
                }
                .buttonStyle(.bordered)
                .controlSize(.large)
            }
        }
    }

    private var noResultsState: some View {
        EmptyStateView(
            symbolName: "magnifyingglass",
            title: "Aucun résultat",
            message: "Aucun projet ne correspond à « \(query) »."
        )
    }
}

#Preview("Tous") {
    NavigationStack {
        ProjectsListView(scope: .all)
    }
    .environment(AppState())
    .modelContainer(SampleData.previewContainer)
}

#Preview("Favoris") {
    NavigationStack {
        ProjectsListView(scope: .favorites)
    }
    .environment(AppState())
    .modelContainer(SampleData.previewContainer)
}
