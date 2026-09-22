import SwiftUI
import SwiftData

/// Everything known about the selected section, editable in place.
///
/// These are the very fields the writing editor shows, on the very same
/// `MusicVideoFacet`. Changing the lyrics here changes them there, because
/// there is only one of them.
struct TimelineInspectorView: View {
    @Bindable var scene: StoryScene
    let project: Project
    /// Closure rather than a value: the inspector only needs the playhead when
    /// a button is pressed, and reading it in the body would redraw on every tick.
    let playheadTime: () -> TimeInterval
    @FocusState.Binding var isEditingText: Bool

    let onSeek: (TimeInterval) -> Void
    let onOpenFullEditor: () -> Void
    let onEditShot: (Shot) -> Void

    @Environment(\.modelContext) private var modelContext

    private var facet: MusicVideoFacet? { scene.musicFacet }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: Spacing.lg) {
                header
                if facet != nil {
                    timing
                    staging
                    lyrics
                    visualIdea
                    shots
                } else {
                    Text("Cette scène n'a pas encore de structure de clip.")
                        .font(.callout)
                        .foregroundStyle(.secondary)
                }
            }
            .padding(Spacing.lg)
        }
    }

    // MARK: Header

    private var header: some View {
        VStack(alignment: .leading, spacing: Spacing.sm) {
            HStack(spacing: Spacing.sm) {
                if let facet {
                    Chip(
                        text: facet.displayName,
                        symbolName: facet.kind.symbolName,
                        tint: facet.kind.isAnchor ? .pink : .purple
                    )
                }
                Spacer(minLength: 0)
                Button(action: onOpenFullEditor) {
                    Label("Tous les détails", systemImage: "slider.horizontal.3")
                        .font(.caption)
                }
                .buttonStyle(.borderless)
            }

            TextField("Titre de la section", text: $scene.title)
                .textFieldStyle(.plain)
                .font(.title3.weight(.semibold))
                .focused($isEditingText)
                .onSubmit { SceneService.commitEdits(to: scene, context: modelContext) }

            Text(rangeText)
                .font(.system(.callout, design: .monospaced))
                .foregroundStyle(.secondary)
                .accessibilityLabel("Section de \(AppFormat.preciseTimecode(startTime)) à \(AppFormat.preciseTimecode(endTime))")
        }
    }

    private var startTime: TimeInterval { facet?.startTime ?? 0 }
    private var endTime: TimeInterval { facet?.endTime ?? startTime }

    private var rangeText: String {
        "\(AppFormat.preciseTimecode(startTime)) → \(AppFormat.preciseTimecode(endTime))"
    }

    // MARK: Timing

    private var timing: some View {
        VStack(alignment: .leading, spacing: Spacing.sm) {
            SectionHeaderView("Position dans le morceau")

            LabeledContent("Début") {
                HStack(spacing: Spacing.sm) {
                    DurationField(duration: startBinding, focus: $isEditingText)
                    Button("Ici") { startBinding.wrappedValue = playheadTime() }
                        .buttonStyle(.bordered)
                        .controlSize(.small)
                        .help("Utiliser la position de la tête de lecture")
                }
            }

            LabeledContent("Fin") {
                HStack(spacing: Spacing.sm) {
                    DurationField(duration: endBinding, focus: $isEditingText)
                    Button("Ici") { endBinding.wrappedValue = playheadTime() }
                        .buttonStyle(.bordered)
                        .controlSize(.small)
                        .help("Utiliser la position de la tête de lecture")
                }
            }

            HStack(spacing: Spacing.md) {
                Label(
                    facet?.duration.map { AppFormat.preciseTimecode($0) } ?? "—",
                    systemImage: "clock"
                )
                .font(.caption.monospacedDigit())
                .foregroundStyle(.secondary)

                Spacer(minLength: 0)

                Button("Écouter la section") { onSeek(startTime) }
                    .buttonStyle(.borderless)
                    .font(.caption)
            }

            if facet?.startTime == nil {
                Button("Placer à la tête de lecture") {
                    MusicTimelineService.placeOnTrack(scene, at: playheadTime(), in: project, context: modelContext)
                }
                .buttonStyle(.bordered)
            }
        }
    }

    private var startBinding: Binding<TimeInterval> {
        Binding(
            get: { startTime },
            set: { MusicTimelineService.setStart($0, for: scene, in: project, context: modelContext) }
        )
    }

    private var endBinding: Binding<TimeInterval> {
        Binding(
            get: { endTime },
            set: { MusicTimelineService.setEnd($0, for: scene, in: project, context: modelContext) }
        )
    }

    // MARK: Staging

    @ViewBuilder
    private var staging: some View {
        if let facet {
            VStack(alignment: .leading, spacing: Spacing.sm) {
                SectionHeaderView("Mise en scène")

                Picker("Registre", selection: Bindable(facet).performanceMode) {
                    ForEach(MusicPerformanceMode.allCases) { mode in
                        Label(mode.displayName, systemImage: mode.symbolName).tag(mode)
                    }
                }
                .pickerStyle(.menu)

                Picker("Lieu", selection: $scene.location) {
                    Text("Aucun").tag(ProductionLocation?.none)
                    ForEach(project.sortedLocations) { location in
                        Text(location.displayName).tag(ProductionLocation?.some(location))
                    }
                }
                .pickerStyle(.menu)

                if !facet.people.isEmpty {
                    HStack(spacing: Spacing.xs) {
                        ForEach(facet.people) { person in
                            Chip(text: person.displayName, symbolName: "person", style: .neutral)
                        }
                    }
                }

                if !facet.wardrobe.isBlank {
                    labelled("Tenues", facet.wardrobe)
                }
                if !facet.props.isBlank {
                    labelled("Accessoires", facet.props)
                }
                if !scene.notes.isBlank {
                    labelled("Notes de réalisation", scene.notes)
                }
            }
        }
    }

    private func labelled(_ title: String, _ value: String) -> some View {
        VStack(alignment: .leading, spacing: 1) {
            Text(title.uppercased())
                .font(.caption2.weight(.semibold))
                .tracking(0.6)
                .foregroundStyle(.secondary)
            Text(value)
                .font(.callout)
                .fixedSize(horizontal: false, vertical: true)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    // MARK: Writing

    @ViewBuilder
    private var lyrics: some View {
        if let facet {
            VStack(alignment: .leading, spacing: Spacing.sm) {
                SectionHeaderView("Paroles", subtitle: facet.lyricsLineCount > 0
                    ? AppFormat.count(facet.lyricsLineCount, singular: "ligne", plural: "lignes", zero: "")
                    : nil)
                TextField("Les lignes chantées sur cette section", text: Bindable(facet).lyrics, axis: .vertical)
                    .textFieldStyle(.plain)
                    .font(.system(.body, design: .serif))
                    .lineLimit(3...14)
                    .focused($isEditingText)
                    .onChange(of: facet.lyrics) { _, _ in facet.touch() }
                    .padding(Spacing.sm)
                    .background(Surface.card, in: RoundedRectangle(cornerRadius: CornerRadius.small, style: .continuous))
            }
        }
    }

    @ViewBuilder
    private var visualIdea: some View {
        if let facet {
            VStack(alignment: .leading, spacing: Spacing.sm) {
                SectionHeaderView("Idée visuelle")
                TextField("Ce que l'on voit, comment on le filme", text: Bindable(facet).visualIdea, axis: .vertical)
                    .textFieldStyle(.plain)
                    .font(.callout)
                    .lineLimit(2...10)
                    .focused($isEditingText)
                    .onChange(of: facet.visualIdea) { _, _ in facet.touch() }
                    .padding(Spacing.sm)
                    .background(Surface.card, in: RoundedRectangle(cornerRadius: CornerRadius.small, style: .continuous))
            }
        }
    }

    // MARK: Shots

    private var shots: some View {
        VStack(alignment: .leading, spacing: Spacing.sm) {
            SectionHeaderView("Plans", subtitle: shotProgressText) {
                Button {
                    let shot = ShotService.create(in: scene, context: modelContext)
                    onEditShot(shot)
                } label: {
                    Label("Ajouter un plan", systemImage: "plus")
                        .font(.caption)
                }
                .buttonStyle(.borderless)
            }

            if scene.shots.isEmpty {
                Text("Aucun plan sur cette section.")
                    .font(.callout)
                    .foregroundStyle(.secondary)
            } else {
                VStack(spacing: 2) {
                    ForEach(scene.sortedShots) { shot in
                        Button {
                            onEditShot(shot)
                        } label: {
                            HStack(spacing: Spacing.sm) {
                                Text(shot.displayNumber)
                                    .font(.caption.monospacedDigit().weight(.semibold))
                                    .foregroundStyle(.secondary)
                                    .frame(minWidth: 34, alignment: .leading)
                                Text(shot.shotSize.abbreviation)
                                    .font(.caption.weight(.medium))
                                    .foregroundStyle(.teal)
                                    .frame(minWidth: 34, alignment: .leading)
                                Text(shot.displayTitle)
                                    .font(.callout)
                                    .lineLimit(1)
                                Spacer(minLength: Spacing.xs)
                                Image(systemName: shot.status.symbolName)
                                    .font(.caption)
                                    .foregroundStyle(shot.status.tint)
                            }
                            .touchTarget(32)
                        }
                        .buttonStyle(.plain)
                        .accessibilityElement(children: .combine)
                        .accessibilityLabel("Plan \(shot.displayNumber), \(shot.shotSize.displayName), \(shot.displayTitle), \(shot.status.displayName)")
                    }
                }
            }
        }
    }

    private var shotProgressText: String? {
        let progress = scene.shotProgress
        guard progress.total > 0 else { return nil }
        return "\(progress.completed)/\(progress.total) tournés"
    }
}
