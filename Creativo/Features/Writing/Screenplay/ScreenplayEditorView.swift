import SwiftUI
import SwiftData

/// The screenplay editor.
///
/// One continuous document, scene by scene, with typed lines. Scenes are the
/// project's real `StoryScene` objects, so a heading changed here changes the
/// breakdown, the schedule and the budget at the same time.
struct ScreenplayEditorView: View {
    @Bindable var project: Project
    var isFocusMode: Bool = false

    @Environment(\.modelContext) private var modelContext
    @Environment(AppState.self) private var appState

    @FocusState private var focusedElementID: UUID?
    @State private var selectedSceneID: UUID?
    @State private var scrollTarget: UUID?
    @State private var scenePendingDeletion: StoryScene?
    @State private var hasPrepared = false

    private var scenes: [StoryScene] { project.sortedScenes }

    private var focusedElement: ScreenplayElement? {
        guard let id = focusedElementID else { return nil }
        for scene in scenes {
            if let match = scene.screenplayElements.first(where: { $0.id == id }) { return match }
        }
        return nil
    }

    var body: some View {
        WidthReader { width in
            let compact = width.prefersCompactLayout
            HStack(spacing: 0) {
                if !compact && !isFocusMode {
                    ScreenplaySceneNavigator(
                        scenes: scenes,
                        selectedSceneID: $selectedSceneID,
                        onSelect: { scene in
                            selectedSceneID = scene.id
                            scrollTarget = scene.id
                        },
                        onAddScene: addScene
                    )
                    Divider()
                }
                document(compact: compact)
            }
        }
        .navigationTitle("Écriture")
        .inlineNavigationTitle()
        .toolbar { toolbarContent }
        .safeAreaInset(edge: .bottom) { elementBar }
        .onAppear(perform: prepareIfNeeded)
        .confirmationDialog(
            "Supprimer cette scène ?",
            isPresented: deletionBinding,
            presenting: scenePendingDeletion
        ) { scene in
            Button("Supprimer", role: .destructive) { delete(scene) }
            Button("Annuler", role: .cancel) { scenePendingDeletion = nil }
        } message: { scene in
            Text("La scène « \(scene.displayTitle) », son texte et ses \(scene.shots.count) plan(s) seront supprimés.")
        }
    }

    // MARK: Document

    private func document(compact: Bool) -> some View {
        ScrollViewReader { proxy in
            ScrollView {
                LazyVStack(alignment: .leading, spacing: 0) {
                    if !isFocusMode {
                        statusStrip
                            .padding(.bottom, Spacing.md)
                    }

                    if scenes.isEmpty {
                        emptyState
                    } else {
                        ForEach(scenes) { scene in
                            ScreenplaySceneBlock(
                                scene: scene,
                                isCompact: compact,
                                focusedElementID: $focusedElementID,
                                onAddElement: { type in addElement(type, to: scene) },
                                onDeleteScene: { scenePendingDeletion = scene }
                            )
                            Divider().opacity(0.35)
                        }
                        addSceneButton
                            .padding(.top, Spacing.xl)
                    }
                }
                .frame(maxWidth: ScreenplayStyle.pageWidth, alignment: .leading)
                .frame(maxWidth: .infinity, alignment: .center)
                .padding(.horizontal, compact ? Spacing.lg : Spacing.xxl)
                .padding(.top, Spacing.lg)
                .padding(.bottom, Spacing.xxxl)
            }
            .onChange(of: scrollTarget) { _, target in
                guard let target else { return }
                withAnimation(.smooth(duration: 0.3)) {
                    proxy.scrollTo(target, anchor: .top)
                }
            }
        }
    }

    private var statusStrip: some View {
        HStack(spacing: Spacing.lg) {
            Label(ScreenplayFormatter.pageCountText(for: scenes), systemImage: "doc.text")
                .font(.caption.monospacedDigit())
                .foregroundStyle(.secondary)

            Label(
                AppFormat.count(scenes.count, singular: "scène", plural: "scènes", zero: "Aucune scène"),
                systemImage: "list.bullet.rectangle"
            )
            .font(.caption)
            .foregroundStyle(.secondary)

            Spacer(minLength: Spacing.sm)

            AutosaveIndicator(date: project.updatedAt)
        }
        .padding(.horizontal, Spacing.xs)
    }

    private var addSceneButton: some View {
        Button(action: addScene) {
            Label("Nouvelle scène", systemImage: "plus")
                .font(.callout)
                .frame(maxWidth: .infinity)
                .touchTarget(40)
        }
        .buttonStyle(.bordered)
    }

    @ViewBuilder
    private var elementBar: some View {
        if let element = focusedElement {
            ScreenplayElementBar(
                currentType: element.type,
                onChangeType: { type in
                    ScreenplayService.setType(type, on: element, context: modelContext)
                },
                onInsert: {
                    if let inserted = ScreenplayService.insert(after: element, context: modelContext) {
                        focusedElementID = inserted.id
                    }
                },
                onDelete: {
                    focusedElementID = nil
                    ScreenplayService.delete(element, context: modelContext)
                }
            )
        }
    }

    private var emptyState: some View {
        EmptyStateView(
            symbolName: "doc.text",
            title: "Page blanche",
            message: "Créez votre première scène. Chaque scène porte son intérieur ou extérieur, son lieu et son moment, et ces informations alimentent directement le découpage, le planning et le budget.",
            tint: .blue
        ) {
            Button(action: addScene) {
                Label("Créer la première scène", systemImage: "plus")
                    .touchTarget()
                    .padding(.horizontal, Spacing.sm)
            }
            .buttonStyle(.borderedProminent)
            .controlSize(.large)
        }
        .frame(minHeight: 360)
    }

    // MARK: Toolbar

    @ToolbarContentBuilder
    private var toolbarContent: some ToolbarContent {
        ToolbarItem(placement: .primaryAction) {
            Button(action: addScene) {
                Label("Nouvelle scène", systemImage: "plus")
            }
            .help("Nouvelle scène (⌘⇧N)")
            .keyboardShortcut("n", modifiers: [.command, .shift])
        }

        ToolbarItem(placement: .automatic) {
            Button {
                appState.isWritingFocusMode.toggle()
            } label: {
                Label(
                    isFocusMode ? "Quitter le mode focus" : "Mode focus",
                    systemImage: isFocusMode ? "arrow.down.right.and.arrow.up.left" : "arrow.up.left.and.arrow.down.right"
                )
            }
            .keyboardShortcut("f", modifiers: [.command, .shift])
            .help("Mode focus (⌘⇧F)")
        }

        ToolbarItem(placement: .automatic) {
            Menu {
                Button {
                    modelContext.undoManager?.undo()
                } label: {
                    Label("Annuler la dernière modification", systemImage: "arrow.uturn.backward")
                }
                .disabled(modelContext.undoManager?.canUndo != true)

                Button {
                    modelContext.undoManager?.redo()
                } label: {
                    Label("Rétablir", systemImage: "arrow.uturn.forward")
                }
                .disabled(modelContext.undoManager?.canRedo != true)

                Divider()

                Menu("Aller à la scène") {
                    ForEach(scenes) { scene in
                        Button("\(scene.displayNumber). \(scene.displayTitle)") {
                            scrollTarget = scene.id
                        }
                    }
                }
                .disabled(scenes.isEmpty)

                Button("Renuméroter les scènes") {
                    SceneService.renumberSequentially(project, context: modelContext)
                }
                .disabled(scenes.isEmpty)

                Button("Nettoyer les lignes vides") {
                    for scene in scenes {
                        ScreenplayService.trimTrailingEmptyElements(in: scene, context: modelContext)
                    }
                }
                .disabled(scenes.isEmpty)
            } label: {
                Label("Plus", systemImage: "ellipsis.circle")
            }
        }
    }

    // MARK: Actions

    private var deletionBinding: Binding<Bool> {
        Binding(
            get: { scenePendingDeletion != nil },
            set: { if !$0 { scenePendingDeletion = nil } }
        )
    }

    /// Imports screenplays written before this phase, once per appearance.
    private func prepareIfNeeded() {
        guard !hasPrepared else { return }
        hasPrepared = true
        ScreenplayService.prepare(project, context: modelContext)
    }

    private func addScene() {
        let scene = SceneService.create(in: project, context: modelContext)
        let element = ScreenplayService.append(.action, to: scene, context: modelContext)
        selectedSceneID = scene.id
        scrollTarget = scene.id
        focusedElementID = element.id
    }

    private func addElement(_ type: ScreenplayElementType, to scene: StoryScene) {
        let element = ScreenplayService.append(type, to: scene, context: modelContext)
        focusedElementID = element.id
    }

    private func delete(_ scene: StoryScene) {
        scenePendingDeletion = nil
        if let id = focusedElementID, scene.screenplayElements.contains(where: { $0.id == id }) {
            focusedElementID = nil
        }
        if selectedSceneID == scene.id { selectedSceneID = nil }
        SceneService.delete(scene, context: modelContext)
    }
}
