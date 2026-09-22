import SwiftUI
import SwiftData

/// The scene breakdown of a project: create, reorder, edit, delete.
struct SceneListView: View {
    @Bindable var project: Project

    @Environment(\.modelContext) private var modelContext
    @State private var query = ""
    @State private var selectedScene: StoryScene?
    @State private var scenePendingDeletion: StoryScene?

    private var scenes: [StoryScene] {
        SceneService.filter(project.sortedScenes, query: query)
    }

    /// Dragging only makes sense when the list shows every scene in order.
    private var isReorderable: Bool { query.isBlank }

    var body: some View {
        Group {
            if project.scenes.isEmpty {
                emptyState
            } else if scenes.isEmpty {
                EmptyStateView(
                    symbolName: "magnifyingglass",
                    title: "Aucun résultat",
                    message: "Aucune scène ne correspond à « \(query) »."
                )
            } else {
                list
            }
        }
        .navigationTitle("Scènes")
        .inlineNavigationTitle()
        .searchable(text: $query, prompt: "Rechercher une scène")
        .navigationDestination(item: $selectedScene) { scene in
            SceneEditorView(scene: scene)
        }
        .toolbar {
            #if os(iOS)
            ToolbarItem(placement: .topBarLeading) {
                EditButton()
            }
            #endif
            ToolbarItem(placement: .primaryAction) {
                Button {
                    addScene()
                } label: {
                    Label("Nouvelle scène", systemImage: "plus")
                }
            }
            ToolbarItem(placement: .automatic) {
                Menu {
                    Button("Renuméroter les scènes") {
                        SceneService.renumberSequentially(project, in: modelContext)
                    }
                    .disabled(project.scenes.isEmpty)
                } label: {
                    Label("Plus", systemImage: "ellipsis.circle")
                }
            }
        }
        .confirmationDialog(
            "Supprimer cette scène ?",
            isPresented: deletionBinding,
            presenting: scenePendingDeletion
        ) { scene in
            Button("Supprimer", role: .destructive) { delete(scene) }
            Button("Annuler", role: .cancel) { scenePendingDeletion = nil }
        } message: { scene in
            Text("La scène « \(scene.displayTitle) » et ses \(scene.shots.count) plan(s) seront supprimés.")
        }
    }

    // MARK: List

    private var list: some View {
        List {
            Section {
                ForEach(scenes) { scene in
                    Button {
                        selectedScene = scene
                    } label: {
                        SceneRow(scene: scene)
                    }
                    .buttonStyle(.plain)
                    .contextMenu { contextMenu(for: scene) }
                    .swipeActions(edge: .trailing) {
                        Button(role: .destructive) {
                            scenePendingDeletion = scene
                        } label: {
                            Label("Supprimer", systemImage: "trash")
                        }
                    }
                }
                .onMove(perform: isReorderable ? move : nil)
            } header: {
                header
            }
        }
    }

    private var header: some View {
        HStack {
            Text(AppFormat.count(project.scenes.count, singular: "scène", plural: "scènes", zero: "Aucune scène"))
            Spacer()
            let duration = project.scenes.reduce(0) { $0 + $1.estimatedDuration }
            if duration > 0 {
                Text("≈ \(AppFormat.duration(duration))")
                    .monospacedDigit()
            }
        }
        .font(.caption)
        .foregroundStyle(.secondary)
        .textCase(nil)
    }

    @ViewBuilder
    private func contextMenu(for scene: StoryScene) -> some View {
        Button("Modifier") { selectedScene = scene }
        Button("Monter") { SceneService.shift(scene, by: -1, in: modelContext) }
            .disabled(!isReorderable || scene.orderIndex == 0)
        Button("Descendre") { SceneService.shift(scene, by: 1, in: modelContext) }
            .disabled(!isReorderable || scene.orderIndex >= project.scenes.count - 1)
        Menu("Statut") {
            ForEach(SceneStatus.allCases) { status in
                Button {
                    scene.status = status
                    SceneService.commitEdits(to: scene, in: modelContext)
                } label: {
                    Label(status.displayName, systemImage: status.symbolName)
                }
            }
        }
        Divider()
        Button("Supprimer…", role: .destructive) { scenePendingDeletion = scene }
    }

    private var emptyState: some View {
        EmptyStateView(
            symbolName: "list.bullet.rectangle",
            title: "Aucune scène",
            message: "Découpez votre projet en scènes. Chaque scène porte son intention, son lieu, son moment et ses plans.",
            tint: .blue
        ) {
            Button {
                addScene()
            } label: {
                Label("Créer la première scène", systemImage: "plus")
                    .touchTarget()
                    .padding(.horizontal, Spacing.sm)
            }
            .buttonStyle(.borderedProminent)
            .controlSize(.large)
        }
    }

    // MARK: Actions

    private var deletionBinding: Binding<Bool> {
        Binding(
            get: { scenePendingDeletion != nil },
            set: { if !$0 { scenePendingDeletion = nil } }
        )
    }

    private func addScene() {
        let scene = SceneService.create(in: project, in: modelContext)
        selectedScene = scene
    }

    private func move(from offsets: IndexSet, to destination: Int) {
        SceneService.move(fromOffsets: offsets, toOffset: destination, in: project, context: modelContext)
    }

    private func delete(_ scene: StoryScene) {
        if selectedScene?.id == scene.id { selectedScene = nil }
        scenePendingDeletion = nil
        SceneService.delete(scene, in: modelContext)
    }
}

#Preview {
    NavigationStack {
        SceneListView(project: SampleData.previewProject())
    }
    .environment(AppState())
    .modelContainer(SampleData.previewContainer)
}
