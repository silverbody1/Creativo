import SwiftUI
import SwiftData

/// The music-video writing surface: the structure of the song, section by section.
///
/// Each section is a real scene carrying a music facet, so its shots, its
/// location and its shooting day are the project's, not a copy. Sections
/// written before this phase keep everything they had and simply gain the
/// facet, with their kind read from their title.
struct MusicVideoWritingView: View {
    @Bindable var project: Project
    var isFocusMode: Bool = false

    @Environment(\.modelContext) private var modelContext
    @Environment(AppState.self) private var appState

    @State private var expandedSections: Set<UUID> = []
    @State private var sectionBeingEdited: StoryScene?
    @State private var sectionPendingDeletion: StoryScene?
    @State private var hasPrepared = false

    private var sections: [StoryScene] { project.musicSections }

    var body: some View {
        Group {
            if sections.isEmpty {
                emptyState
            } else {
                list
            }
        }
        .navigationTitle("Écriture")
        .inlineNavigationTitle()
        .toolbar { toolbarContent }
        .onAppear(perform: prepareIfNeeded)
        .sheet(item: $sectionBeingEdited) { scene in
            MusicVideoSectionEditor(scene: scene)
        }
        .confirmationDialog(
            "Supprimer cette section ?",
            isPresented: deletionBinding,
            presenting: sectionPendingDeletion
        ) { scene in
            Button("Supprimer", role: .destructive) {
                MusicVideoService.delete(scene, context: modelContext)
                sectionPendingDeletion = nil
            }
            Button("Annuler", role: .cancel) { sectionPendingDeletion = nil }
        } message: { scene in
            Text("« \(scene.musicSectionName) » et ses \(scene.shots.count) plan(s) seront supprimés.")
        }
    }

    // MARK: List

    private var list: some View {
        List {
            if !isFocusMode {
                Section {
                    summaryCard
                        .listRowInsets(EdgeInsets())
                        .listRowBackground(Color.clear)
                }
            }

            Section {
                ForEach(sections) { scene in
                    row(for: scene)
                        .swipeActions(edge: .trailing) {
                            Button(role: .destructive) {
                                sectionPendingDeletion = scene
                            } label: {
                                Label("Supprimer", systemImage: "trash")
                            }
                        }
                }
                .onMove(perform: move)
            } header: {
                Text("Structure du morceau")
                    .textCase(nil)
            }

            Section {
                addSectionMenu
            }
        }
    }

    @ViewBuilder
    private func row(for scene: StoryScene) -> some View {
        let facet = scene.musicFacet
        let isExpanded = expandedSections.contains(scene.id)

        VStack(alignment: .leading, spacing: Spacing.sm) {
            HStack(spacing: Spacing.sm) {
                Button {
                    toggle(scene)
                } label: {
                    Image(systemName: isExpanded ? "chevron.down" : "chevron.right")
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(.secondary)
                        .frame(width: 22, height: 22)
                        .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
                .accessibilityLabel(isExpanded ? "Replier la section" : "Déplier la section")

                if let facet {
                    Chip(
                        text: facet.displayName,
                        symbolName: facet.kind.symbolName,
                        tint: facet.kind.isAnchor ? .pink : .purple
                    )
                }

                Text(scene.title.isBlank ? "Sans titre" : scene.title)
                    .font(.body.weight(.medium))
                    .lineLimit(1)

                Spacer(minLength: Spacing.xs)

                if let range = facet?.timecodeRange {
                    Text(range)
                        .font(.caption.monospacedDigit())
                        .foregroundStyle(.secondary)
                }

                if !scene.shots.isEmpty {
                    let progress = scene.shotProgress
                    Text("\(progress.completed)/\(progress.total)")
                        .font(.caption.monospacedDigit())
                        .foregroundStyle(.tertiary)
                        .help("Plans tournés")
                }

                Button {
                    sectionBeingEdited = scene
                } label: {
                    Image(systemName: "slider.horizontal.3")
                        .font(.caption)
                        .foregroundStyle(.tertiary)
                        .frame(width: 24, height: 24)
                        .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
                .accessibilityLabel("Détails de la section")
            }

            if let facet {
                metadataLine(facet, scene: scene)
                if isExpanded {
                    expandedContent(facet)
                }
            }
        }
        .padding(.vertical, Spacing.xs)
        .contextMenu { menu(for: scene) }
    }

    private func metadataLine(_ facet: MusicVideoFacet, scene: StoryScene) -> some View {
        HStack(spacing: Spacing.sm) {
            Chip(text: facet.performanceMode.displayName, symbolName: facet.performanceMode.symbolName, style: .neutral)
            if let location = scene.location {
                Chip(text: location.displayName, symbolName: "mappin", style: .neutral)
            }
            if !facet.people.isEmpty {
                Chip(
                    text: AppFormat.count(facet.people.count, singular: "personne", plural: "personnes", zero: ""),
                    symbolName: "person.2",
                    style: .neutral
                )
            }
            Spacer(minLength: 0)
        }
        .padding(.leading, 26)
    }

    @ViewBuilder
    private func expandedContent(_ facet: MusicVideoFacet) -> some View {
        VStack(alignment: .leading, spacing: Spacing.md) {
            VStack(alignment: .leading, spacing: Spacing.xs) {
                Text("PAROLES")
                    .font(.caption2.weight(.semibold))
                    .tracking(0.6)
                    .foregroundStyle(.secondary)
                TextField(
                    "Les lignes chantées sur cette section",
                    text: Bindable(facet).lyrics,
                    axis: .vertical
                )
                .textFieldStyle(.plain)
                .font(.system(.body, design: .serif))
                .lineLimit(2...12)
                .onChange(of: facet.lyrics) { _, _ in facet.touch() }
            }

            VStack(alignment: .leading, spacing: Spacing.xs) {
                Text("IDÉE VISUELLE")
                    .font(.caption2.weight(.semibold))
                    .tracking(0.6)
                    .foregroundStyle(.secondary)
                TextField(
                    "Ce que l'on voit, comment on le filme",
                    text: Bindable(facet).visualIdea,
                    axis: .vertical
                )
                .textFieldStyle(.plain)
                .font(.callout)
                .lineLimit(2...8)
                .onChange(of: facet.visualIdea) { _, _ in facet.touch() }
            }

            Button("Tous les détails de la section") {
                sectionBeingEdited = facet.scene
            }
            .buttonStyle(.borderless)
            .font(.callout)
        }
        .padding(.leading, 26)
        .padding(.top, Spacing.xs)
    }

    private var summaryCard: some View {
        VStack(alignment: .leading, spacing: Spacing.md) {
            HStack(alignment: .top, spacing: Spacing.lg) {
                figure(
                    "Sections",
                    "\(sections.count)",
                    tint: .purple
                )
                figure(
                    "Durée du morceau",
                    MusicVideoService.trackDuration(of: project).map { AppFormat.timecode($0) } ?? "—",
                    tint: .pink
                )
                figure(
                    "Lignes de paroles",
                    "\(MusicVideoService.lyricsLineCount(of: project))",
                    tint: .indigo
                )
                figure(
                    "Plans",
                    "\(project.allShots.count)",
                    tint: .teal
                )
            }
            HStack {
                Spacer(minLength: 0)
                AutosaveIndicator(date: project.updatedAt)
            }
        }
        .cardSurface()
        .padding(.vertical, Spacing.sm)
    }

    private func figure(_ label: String, _ value: String, tint: Color) -> some View {
        VStack(alignment: .leading, spacing: Spacing.xxs) {
            Text(label.uppercased())
                .font(.caption2.weight(.semibold))
                .tracking(0.6)
                .foregroundStyle(.secondary)
            Text(value)
                .font(.system(.title3, design: .rounded, weight: .semibold))
                .monospacedDigit()
                .foregroundStyle(tint)
                .lineLimit(1)
                .minimumScaleFactor(0.6)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private var addSectionMenu: some View {
        Menu {
            ForEach(MusicSectionKind.allCases) { kind in
                Button {
                    add(kind)
                } label: {
                    Label(kind.displayName, systemImage: kind.symbolName)
                }
            }
        } label: {
            Label("Ajouter une section", systemImage: "plus")
                .touchTarget()
        } primaryAction: {
            add(nil)
        }
        .menuStyle(.button)
        .buttonStyle(.borderless)
    }

    @ViewBuilder
    private func menu(for scene: StoryScene) -> some View {
        Button("Détails de la section") { sectionBeingEdited = scene }
        if let facet = scene.musicFacet {
            Menu("Type") {
                ForEach(MusicSectionKind.allCases) { kind in
                    Button {
                        facet.kind = kind
                        MusicVideoService.commitEdits(to: facet, context: modelContext)
                    } label: {
                        Label(kind.displayName, systemImage: kind.symbolName)
                    }
                }
            }
            Menu("Registre") {
                ForEach(MusicPerformanceMode.allCases) { mode in
                    Button {
                        facet.performanceMode = mode
                        MusicVideoService.commitEdits(to: facet, context: modelContext)
                    } label: {
                        Label(mode.displayName, systemImage: mode.symbolName)
                    }
                }
            }
        }
        Divider()
        Button("Monter") { MusicVideoService.shift(scene, by: -1, context: modelContext) }
        Button("Descendre") { MusicVideoService.shift(scene, by: 1, context: modelContext) }
        Divider()
        Button("Supprimer…", role: .destructive) { sectionPendingDeletion = scene }
    }

    private var emptyState: some View {
        EmptyStateView(
            symbolName: "music.note.list",
            title: "Structure du clip",
            message: "Posez la structure du morceau : intro, couplets, refrains, pont, outro. Chaque section porte ses paroles, son intention visuelle, ses tenues et ses plans.",
            tint: .purple
        ) {
            VStack(spacing: Spacing.sm) {
                Button {
                    buildStarterStructure()
                } label: {
                    Label("Partir d'une structure type", systemImage: "list.bullet.indent")
                        .touchTarget()
                        .padding(.horizontal, Spacing.sm)
                }
                .buttonStyle(.borderedProminent)
                .controlSize(.large)

                Button("Ajouter une seule section") { add(nil) }
                    .buttonStyle(.borderless)
            }
        }
    }

    // MARK: Toolbar

    @ToolbarContentBuilder
    private var toolbarContent: some ToolbarContent {
        ToolbarItem(placement: .primaryAction) {
            Menu {
                ForEach(MusicSectionKind.allCases) { kind in
                    Button {
                        add(kind)
                    } label: {
                        Label(kind.displayName, systemImage: kind.symbolName)
                    }
                }
            } label: {
                Label("Ajouter une section", systemImage: "plus")
            }
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

                Button("Tout déplier") { expandedSections = Set(sections.map(\.id)) }
                Button("Tout replier") { expandedSections.removeAll() }
            } label: {
                Label("Plus", systemImage: "ellipsis.circle")
            }
        }
    }

    // MARK: Actions

    private var deletionBinding: Binding<Bool> {
        Binding(
            get: { sectionPendingDeletion != nil },
            set: { if !$0 { sectionPendingDeletion = nil } }
        )
    }

    private func prepareIfNeeded() {
        guard !hasPrepared else { return }
        hasPrepared = true
        MusicVideoService.prepare(project, context: modelContext)
    }

    private func toggle(_ scene: StoryScene) {
        if expandedSections.contains(scene.id) {
            expandedSections.remove(scene.id)
        } else {
            expandedSections.insert(scene.id)
        }
    }

    private func add(_ kind: MusicSectionKind?) {
        let scene = MusicVideoService.createSection(in: project, kind: kind, context: modelContext)
        expandedSections.insert(scene.id)
    }

    private func buildStarterStructure() {
        let plan: [MusicSectionKind] = [.intro, .verse, .preChorus, .chorus, .verse, .chorus, .bridge, .chorus, .outro]
        for kind in plan {
            MusicVideoService.createSection(in: project, kind: kind, context: modelContext)
        }
    }

    private func move(from offsets: IndexSet, to destination: Int) {
        MusicVideoService.move(fromOffsets: offsets, toOffset: destination, in: project, context: modelContext)
    }
}
