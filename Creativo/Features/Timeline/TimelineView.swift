import SwiftUI
import SwiftData
import UniformTypeIdentifiers

/// The clip's timeline: the track, its structure, and what each passage is for.
///
/// This is preproduction, not editing. There is one audio track, the sections
/// of the song, markers, and the direction notes attached to them. The playhead
/// position lives in `AudioPlaybackController` and never reaches SwiftData.
struct TimelineView: View {
    @Bindable var project: Project

    @Environment(\.modelContext) private var modelContext

    @State private var playback = AudioPlaybackController()
    @State private var samples: WaveformSamples = .empty
    @State private var isLoadingWaveform = false
    @State private var waveformError: String?

    @State private var pixelsPerSecond: CGFloat = 0
    @State private var viewportWidth: CGFloat = 0
    @State private var pinchBasePixelsPerSecond: CGFloat?
    @State private var isSnapEnabled = true

    @State private var selectedSceneID: UUID?
    @State private var markerBeingEdited: TimelineMarker?
    @State private var shotBeingEdited: Shot?
    @State private var sceneBeingEdited: StoryScene?

    @State private var isImporterPresented = false
    @State private var isReplacingTrack = false
    @State private var isConfirmingRemoval = false
    @State private var importError: String?
    @State private var hasPrepared = false

    @FocusState private var isEditingText: Bool

    private let rulerHeight: CGFloat = 30
    private let waveformHeight: CGFloat = 132
    private let sectionsHeight: CGFloat = 56
    private let markersHeight: CGFloat = 34

    private var lanesHeight: CGFloat {
        rulerHeight + waveformHeight + sectionsHeight + markersHeight
    }

    private var duration: TimeInterval {
        max(playback.duration, project.timelineDuration)
    }

    private var selectedScene: StoryScene? {
        guard let selectedSceneID else { return nil }
        return project.musicSections.first { $0.id == selectedSceneID }
    }

    private var hasWaveform: Bool { !samples.isEmpty }

    var body: some View {
        VStack(spacing: 0) {
            AudioTrackPanel(
                project: project,
                playback: playback,
                isLoadingWaveform: isLoadingWaveform,
                waveformError: waveformError,
                onImport: { present(replacing: false) },
                onReplace: { present(replacing: true) },
                onRemove: { isConfirmingRemoval = true }
            )

            Divider()

            controlStrip
                .padding(.horizontal, Spacing.lg)
                .padding(.vertical, Spacing.sm)

            Divider()

            WidthReader { width in
                timelineSurface(viewportWidth: width)
                    .onAppear { adopt(width: width) }
                    .onChange(of: width) { _, newValue in adopt(width: newValue) }
            }
            .frame(height: lanesHeight + 16)

            Divider()

            bottomPane
        }
        .navigationTitle("Timeline")
        .inlineNavigationTitle()
        .toolbar { toolbarContent }
        .task(id: project.primaryAudioAsset?.id) { await loadTrack() }
        .onAppear(perform: prepareIfNeeded)
        .onDisappear { playback.unload() }
        .fileImporter(
            isPresented: $isImporterPresented,
            allowedContentTypes: [.audio],
            allowsMultipleSelection: false
        ) { result in
            handleImporterResult(result)
        }
        .sheet(item: $markerBeingEdited) { marker in
            MarkerEditorSheet(marker: marker, project: project)
        }
        .sheet(item: $shotBeingEdited) { shot in
            ShotEditorSheet(shot: shot)
        }
        .sheet(item: $sceneBeingEdited) { scene in
            MusicVideoSectionEditor(scene: scene)
        }
        .alert("Import impossible", isPresented: importErrorBinding) {
            Button("Fermer", role: .cancel) { importError = nil }
        } message: {
            Text(importError ?? "")
        }
        .confirmationDialog(
            "Retirer le morceau du projet ?",
            isPresented: $isConfirmingRemoval
        ) {
            Button("Retirer", role: .destructive) { removeTrack() }
            Button("Annuler", role: .cancel) {}
        } message: {
            Text("Le fichier est supprimé du projet. Vos sections, vos plans et vos repères sont conservés.")
        }
    }

    // MARK: Controls

    private var controlStrip: some View {
        HStack(spacing: Spacing.lg) {
            TimelineTransportBar(playback: playback, shortcutsEnabled: shortcutsActive)

            Spacer(minLength: Spacing.sm)

            Toggle(isOn: $isSnapEnabled) {
                Label("Aimant", systemImage: "magnet")
                    .labelStyle(.iconOnly)
            }
            .toggleStyle(.button)
            .help("Aimanter sur les sections, les repères et la tête de lecture")
            .accessibilityLabel("Aimantation")

            HStack(spacing: Spacing.xs) {
                Button {
                    zoom(by: 1 / 1.6)
                } label: {
                    Image(systemName: "minus.magnifyingglass")
                }
                .buttonStyle(.borderless)
                .keyboardShortcut(shortcut("-", modifiers: .command))
                .accessibilityLabel("Dézoomer")

                Button("Tout") { fitAll() }
                    .buttonStyle(.borderless)
                    .font(.caption)
                    .keyboardShortcut(shortcut("0", modifiers: .command))
                    .help("Voir tout le morceau")

                Button {
                    zoom(by: 1.6)
                } label: {
                    Image(systemName: "plus.magnifyingglass")
                }
                .buttonStyle(.borderless)
                .keyboardShortcut(shortcut("=", modifiers: .command))
                .accessibilityLabel("Zoomer")
            }
        }
    }

    // MARK: Timeline surface

    private func timelineSurface(viewportWidth width: CGFloat) -> some View {
        let layout = geometry(for: width)
        let tiles = TimelineTiling.tiles(for: layout)

        return ScrollViewReader { proxy in
            ScrollView(.horizontal) {
                VStack(alignment: .leading, spacing: 0) {
                    TimelineRulerLane(geometry: layout, tiles: tiles, height: rulerHeight)
                        .contentShape(Rectangle())
                        .gesture(
                            DragGesture(minimumDistance: 0)
                                .onChanged { value in
                                    playback.seek(to: layout.time(forX: value.location.x))
                                }
                        )

                    WaveformLane(
                        samples: displayedSamples,
                        geometry: layout,
                        tiles: tiles,
                        height: waveformHeight,
                        tint: hasWaveform ? .teal : .gray,
                        isPlaceholder: !hasWaveform
                    )
                    .contentShape(Rectangle())
                    .onTapGesture { location in
                        playback.seek(to: layout.time(forX: location.x))
                    }

                    TimelineSectionsLane(
                        project: project,
                        geometry: layout,
                        selectedSceneID: selectedSceneID,
                        makeSnapper: { makeSnapper(for: layout) },
                        height: sectionsHeight,
                        onSelect: { scene in select(scene, seek: false) },
                        onCommitBoundary: { previous, next, time in
                            MusicTimelineService.setBoundary(
                                between: previous,
                                and: next,
                                to: time,
                                in: project,
                                context: modelContext
                            )
                        }
                    )

                    TimelineMarkersLane(
                        markers: project.sortedMarkers,
                        geometry: layout,
                        makeSnapper: { makeSnapper(for: layout) },
                        height: markersHeight,
                        onSelect: { marker in playback.seek(to: marker.time) },
                        onEdit: { marker in markerBeingEdited = marker },
                        onCommitMove: { marker, time in
                            MusicTimelineService.move(marker, to: time, in: project, context: modelContext)
                        }
                    )
                }
                .frame(width: layout.contentWidth, alignment: .leading)
                .background(alignment: .topLeading) { scrollAnchors(layout: layout) }
                .overlay(alignment: .topLeading) {
                    TimelinePlayheadView(
                        playback: playback,
                        geometry: layout,
                        height: lanesHeight
                    ) { second in
                        withAnimation(.easeOut(duration: 0.2)) {
                            proxy.scrollTo(anchorID(for: second), anchor: .center)
                        }
                    }
                }
                .gesture(
                    MagnifyGesture()
                        .onChanged { value in
                            let base = pinchBasePixelsPerSecond ?? layout.pixelsPerSecond
                            pinchBasePixelsPerSecond = base
                            setZoom(base * value.magnification)
                        }
                        .onEnded { _ in pinchBasePixelsPerSecond = nil }
                )
            }
            .scrollIndicators(.visible)
        }
    }

    /// Invisible waypoints so the playhead can be scrolled into view.
    private func scrollAnchors(layout: TimelineGeometry) -> some View {
        let spacing = layout.width(forDuration: anchorInterval)
        let count = max(Int((duration / anchorInterval).rounded(.up)) + 1, 1)
        return HStack(spacing: 0) {
            ForEach(Array(0..<count), id: \.self) { index in
                Color.clear
                    .frame(width: max(spacing, 1), height: 1)
                    .id(anchorID(for: TimeInterval(index) * anchorInterval))
            }
        }
        .allowsHitTesting(false)
    }

    private var anchorInterval: TimeInterval { 5 }

    private func anchorID(for time: TimeInterval) -> Int {
        max(Int(time / anchorInterval), 0)
    }

    private var displayedSamples: WaveformSamples {
        if !samples.isEmpty { return samples }
        return WaveformSamples.placeholder(duration: max(duration, 1))
    }

    // MARK: Bottom pane

    private var bottomPane: some View {
        WidthReader { width in
            Group {
                if width.prefersCompactLayout {
                    inspectorPane
                } else {
                    HStack(spacing: 0) {
                        SongStructureView(
                            project: project,
                            selectedSceneID: selectedSceneID,
                            onSelect: { scene in select(scene, seek: true) }
                        )
                        .frame(width: 244)

                        Divider()

                        inspectorPane
                    }
                }
            }
        }
    }

    @ViewBuilder
    private var inspectorPane: some View {
        if let scene = selectedScene {
            TimelineInspectorView(
                scene: scene,
                project: project,
                playheadTime: { playback.currentTime },
                isEditingText: $isEditingText,
                onSeek: { time in playback.seek(to: time) },
                onOpenFullEditor: { sceneBeingEdited = scene },
                onEditShot: { shot in shotBeingEdited = shot }
            )
        } else {
            EmptyStateView(
                symbolName: "rectangle.split.3x1",
                title: "Aucune section sélectionnée",
                message: project.musicSections.isEmpty
                    ? "Placez la tête de lecture puis ajoutez une section pour commencer à structurer le morceau."
                    : "Choisissez une section sur la timeline ou dans la structure pour l'inspecter.",
                tint: .purple
            ) {
                Button {
                    addSection(nil)
                } label: {
                    Label("Ajouter une section ici", systemImage: "plus")
                        .touchTarget()
                        .padding(.horizontal, Spacing.sm)
                }
                .buttonStyle(.borderedProminent)
            }
        }
    }

    // MARK: Toolbar

    @ToolbarContentBuilder
    private var toolbarContent: some ToolbarContent {
        ToolbarItem(placement: .primaryAction) {
            Menu {
                Button("Section à la tête de lecture") { addSection(nil) }
                Divider()
                ForEach(MusicSectionKind.allCases) { kind in
                    Button {
                        addSection(kind)
                    } label: {
                        Label(kind.displayName, systemImage: kind.symbolName)
                    }
                }
            } label: {
                Label("Ajouter une section", systemImage: "plus.rectangle")
            } primaryAction: {
                addSection(nil)
            }
            .keyboardShortcut(shortcut("s", modifiers: [.command, .shift]))
        }

        ToolbarItem(placement: .automatic) {
            Menu {
                ForEach(TimelineMarkerType.allCases) { type in
                    Button {
                        addMarker(type)
                    } label: {
                        Label(type.displayName, systemImage: type.symbolName)
                    }
                }
            } label: {
                Label("Ajouter un repère", systemImage: "mappin.and.ellipse")
            } primaryAction: {
                addMarker(.standard)
            }
            .keyboardShortcut(shortcut("m", modifiers: []))
            .help("Poser un repère à la tête de lecture (M)")
        }

        ToolbarItem(placement: .automatic) {
            Menu {
                Button("Importer un morceau…") { present(replacing: false) }
                    .disabled(project.primaryAudioAsset != nil)
                Button("Remplacer le morceau…") { present(replacing: true) }
                    .disabled(project.primaryAudioAsset == nil)
                Divider()
                Button("Recadrer les sections sur le morceau") {
                    MusicTimelineService.clampToDuration(project, context: modelContext)
                }
                .disabled(duration <= 0)
                Button("Régénérer la forme d'onde") {
                    Task { await regenerateWaveform() }
                }
                .disabled(project.primaryAudioAsset == nil)
            } label: {
                Label("Plus", systemImage: "ellipsis.circle")
            }
        }
    }

    // MARK: Zoom

    private func geometry(for width: CGFloat) -> TimelineGeometry {
        let usable = max(width - 8, 1)
        let scale = pixelsPerSecond > 0
            ? pixelsPerSecond
            : TimelineGeometry.fittingPixelsPerSecond(duration: duration, availableWidth: usable)
        return TimelineGeometry(duration: duration, pixelsPerSecond: scale)
    }

    private func adopt(width: CGFloat) {
        guard width > 0 else { return }
        viewportWidth = width
        playback.adoptDurationIfNeeded(project.timelineDuration)
        if pixelsPerSecond == 0 { fitAll() }
    }

    private func fitAll() {
        let usable = max(viewportWidth - 8, 1)
        setZoom(TimelineGeometry.fittingPixelsPerSecond(duration: duration, availableWidth: usable))
    }

    private func zoom(by factor: CGFloat) {
        let current = pixelsPerSecond > 0
            ? pixelsPerSecond
            : TimelineGeometry.fittingPixelsPerSecond(duration: duration, availableWidth: max(viewportWidth - 8, 1))
        setZoom(current * factor)
    }

    private func setZoom(_ value: CGFloat) {
        pixelsPerSecond = min(
            max(value, TimelineGeometry.minimumPixelsPerSecond),
            TimelineGeometry.maximumPixelsPerSecond
        )
    }

    private func makeSnapper(for geometry: TimelineGeometry) -> TimelineSnapper {
        TimelineSnapper(
            candidates: MusicTimelineService.snapCandidates(
                for: project,
                playhead: playback.currentTime
            ),
            tolerance: TimelineSnapper.tolerance(forPixels: 8, pixelsPerSecond: geometry.pixelsPerSecond),
            isEnabled: isSnapEnabled
        )
    }

    // MARK: Actions

    /// Space, M and the arrow keys are only the timeline's while nothing else
    /// wants the keyboard: not a text field, not a sheet, not the file panel.
    private var shortcutsActive: Bool {
        !isEditingText
            && markerBeingEdited == nil
            && shotBeingEdited == nil
            && sceneBeingEdited == nil
            && !isImporterPresented
    }

    private func shortcut(_ key: KeyEquivalent, modifiers: EventModifiers) -> KeyboardShortcut? {
        shortcutsActive ? KeyboardShortcut(key, modifiers: modifiers) : nil
    }

    private func prepareIfNeeded() {
        guard !hasPrepared else { return }
        hasPrepared = true
        MusicVideoService.prepare(project, context: modelContext)
        if selectedSceneID == nil {
            selectedSceneID = project.timedSections.first?.id ?? project.musicSections.first?.id
        }
    }

    private func select(_ scene: StoryScene, seek: Bool) {
        selectedSceneID = scene.id
        if seek, let start = scene.musicFacet?.startTime {
            playback.seek(to: start)
        }
    }

    private func addSection(_ kind: MusicSectionKind?) {
        let scene = MusicTimelineService.createSection(
            at: playback.currentTime,
            kind: kind,
            in: project,
            context: modelContext
        )
        selectedSceneID = scene.id
    }

    private func addMarker(_ type: TimelineMarkerType) {
        let marker = MusicTimelineService.addMarker(
            at: playback.currentTime,
            type: type,
            in: project,
            context: modelContext
        )
        markerBeingEdited = marker
    }

    // MARK: Media

    private var importErrorBinding: Binding<Bool> {
        Binding(
            get: { importError != nil },
            set: { if !$0 { importError = nil } }
        )
    }

    private func present(replacing: Bool) {
        isReplacingTrack = replacing
        isImporterPresented = true
    }

    private func handleImporterResult(_ result: Result<[URL], Error>) {
        switch result {
        case .success(let urls):
            guard let url = urls.first else { return }
            do {
                if isReplacingTrack {
                    try MediaImportService.replaceAudio(of: project, with: url, context: modelContext)
                } else {
                    try MediaImportService.importAudio(from: url, into: project, context: modelContext)
                }
            } catch {
                importError = error.localizedDescription
            }
        case .failure(let error):
            importError = error.localizedDescription
        }
    }

    private func removeTrack() {
        guard let asset = project.primaryAudioAsset else { return }
        playback.unload()
        samples = .empty
        MediaImportService.remove(asset, from: project, context: modelContext)
    }

    private func loadTrack() async {
        waveformError = nil

        guard let asset = project.primaryAudioAsset else {
            playback.unload()
            playback.adoptDurationIfNeeded(project.timelineDuration)
            samples = .empty
            return
        }

        guard asset.isAvailable else {
            playback.unload()
            playback.adoptDurationIfNeeded(project.timelineDuration)
            samples = .empty
            waveformError = "Le fichier « \(asset.originalFilename) » est introuvable."
            return
        }

        playback.load(assetID: asset.id, url: asset.fileURL, fallbackDuration: asset.duration)

        isLoadingWaveform = true
        defer { isLoadingWaveform = false }
        do {
            samples = try await WaveformStore.shared.waveform(assetID: asset.id, url: asset.fileURL)
        } catch {
            samples = .empty
            waveformError = error.localizedDescription
        }
    }

    private func regenerateWaveform() async {
        guard let asset = project.primaryAudioAsset, asset.isAvailable else { return }
        await WaveformStore.shared.invalidate(assetID: asset.id)
        samples = .empty
        await loadTrack()
    }
}

#Preview {
    NavigationStack {
        TimelineView(project: SampleData.previewProject())
    }
    .environment(AppState())
    .modelContainer(SampleData.previewContainer)
}
