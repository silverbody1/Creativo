import SwiftUI
import SwiftData

/// The shot list of a project, grouped by scene, with shooting progress.
struct ShotsView: View {
    @Bindable var project: Project

    @Environment(AppState.self) private var appState
    @Environment(\.modelContext) private var modelContext
    @State private var shotBeingEdited: Shot?
    @State private var shotPendingDeletion: Shot?

    private var progress: (completed: Int, total: Int) { project.shotProgress }

    var body: some View {
        Group {
            if project.scenes.isEmpty {
                noScenesState
            } else if project.allShots.isEmpty {
                noShotsState
            } else {
                list
            }
        }
        .navigationTitle("Plans")
        .inlineNavigationTitle()
        .toolbar {
            ToolbarItem(placement: .primaryAction) {
                Menu {
                    ForEach(project.sortedScenes) { scene in
                        Button("Scène \(scene.displayNumber) — \(scene.displayTitle)") {
                            addShot(to: scene)
                        }
                    }
                } label: {
                    Label("Nouveau plan", systemImage: "plus")
                }
                .disabled(project.scenes.isEmpty)
            }
        }
        .sheet(item: $shotBeingEdited) { shot in
            ShotEditorSheet(shot: shot)
        }
        .confirmationDialog(
            "Supprimer ce plan ?",
            isPresented: deletionBinding,
            presenting: shotPendingDeletion
        ) { shot in
            Button("Supprimer", role: .destructive) {
                ShotService.delete(shot, in: modelContext)
                shotPendingDeletion = nil
            }
            Button("Annuler", role: .cancel) { shotPendingDeletion = nil }
        } message: { shot in
            Text("Le plan « \(shot.displayTitle) » sera définitivement supprimé.")
        }
    }

    // MARK: List

    private var list: some View {
        List {
            Section {
                progressBanner
                    .listRowInsets(EdgeInsets())
                    .listRowBackground(Color.clear)
            }

            ForEach(project.sortedScenes) { scene in
                Section {
                    if scene.shots.isEmpty {
                        Text("Aucun plan dans cette scène.")
                            .font(.callout)
                            .foregroundStyle(.secondary)
                    } else {
                        ForEach(scene.sortedShots) { shot in
                            Button {
                                shotBeingEdited = shot
                            } label: {
                                ShotRow(shot: shot) {
                                    ShotService.advanceStatus(of: shot, in: modelContext)
                                }
                            }
                            .buttonStyle(.plain)
                            .contextMenu { contextMenu(for: shot) }
                            .swipeActions(edge: .trailing) {
                                Button(role: .destructive) {
                                    shotPendingDeletion = shot
                                } label: {
                                    Label("Supprimer", systemImage: "trash")
                                }
                            }
                        }
                        .onMove { offsets, destination in
                            ShotService.move(
                                fromOffsets: offsets,
                                toOffset: destination,
                                in: scene,
                                context: modelContext
                            )
                        }
                    }

                    Button {
                        addShot(to: scene)
                    } label: {
                        Label("Ajouter un plan", systemImage: "plus")
                            .font(.callout)
                    }
                } header: {
                    sceneHeader(scene)
                }
            }
        }
    }

    private func sceneHeader(_ scene: StoryScene) -> some View {
        HStack(spacing: Spacing.sm) {
            Text("Scène \(scene.displayNumber)")
                .font(.caption.weight(.semibold))
            Text(scene.displayTitle)
                .font(.caption)
                .foregroundStyle(.secondary)
                .lineLimit(1)
            Spacer(minLength: Spacing.sm)
            let sceneProgress = scene.shotProgress
            if sceneProgress.total > 0 {
                Text("\(sceneProgress.completed)/\(sceneProgress.total)")
                    .font(.caption.monospacedDigit())
                    .foregroundStyle(.secondary)
            }
        }
        .textCase(nil)
    }

    private var progressBanner: some View {
        VStack(alignment: .leading, spacing: Spacing.sm) {
            HStack(alignment: .firstTextBaseline) {
                Text("\(progress.completed) / \(progress.total)")
                    .font(.system(.title2, design: .rounded, weight: .semibold))
                    .monospacedDigit()
                Text("plans tournés")
                    .font(.callout)
                    .foregroundStyle(.secondary)
                Spacer(minLength: 0)
                if progress.total > 0 {
                    Text(AppFormat.percentage(Double(progress.completed) / Double(progress.total)))
                        .font(.callout.monospacedDigit())
                        .foregroundStyle(.secondary)
                }
            }
            if progress.total > 0 {
                ProgressView(value: Double(progress.completed), total: Double(progress.total))
                    .tint(.teal)
            }
        }
        .cardSurface()
        .padding(.vertical, Spacing.sm)
    }

    @ViewBuilder
    private func contextMenu(for shot: Shot) -> some View {
        Button("Modifier") { shotBeingEdited = shot }
        Menu("Statut") {
            ForEach(ShotStatus.allCases) { status in
                Button {
                    ShotService.setStatus(status, on: shot, in: modelContext)
                } label: {
                    Label(status.displayName, systemImage: status.symbolName)
                }
            }
        }
        Button("Monter") { ShotService.shift(shot, by: -1, in: modelContext) }
        Button("Descendre") { ShotService.shift(shot, by: 1, in: modelContext) }
        Divider()
        Button("Supprimer…", role: .destructive) { shotPendingDeletion = shot }
    }

    // MARK: States

    private var noScenesState: some View {
        EmptyStateView(
            symbolName: "camera.viewfinder",
            title: "Créez d'abord vos scènes",
            message: "Les plans se rattachent à une scène. Découpez votre projet, puis construisez la shot list.",
            tint: .teal
        ) {
            Button {
                appState.workspaceSection = .scenes
            } label: {
                Label("Aller aux scènes", systemImage: "list.bullet.rectangle")
                    .touchTarget()
                    .padding(.horizontal, Spacing.sm)
            }
            .buttonStyle(.borderedProminent)
            .controlSize(.large)
        }
    }

    private var noShotsState: some View {
        EmptyStateView(
            symbolName: "camera.viewfinder",
            title: "Aucun plan",
            message: "Construisez votre shot list : valeur de plan, mouvement, optique et cadence pour chaque plan.",
            tint: .teal
        ) {
            Button {
                if let first = project.sortedScenes.first { addShot(to: first) }
            } label: {
                Label("Créer le premier plan", systemImage: "plus")
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
            get: { shotPendingDeletion != nil },
            set: { if !$0 { shotPendingDeletion = nil } }
        )
    }

    private func addShot(to scene: StoryScene) {
        shotBeingEdited = ShotService.create(in: scene, in: modelContext)
    }
}

#Preview {
    NavigationStack {
        ShotsView(project: SampleData.previewProject())
    }
    .environment(AppState())
    .modelContainer(SampleData.previewContainer)
}
