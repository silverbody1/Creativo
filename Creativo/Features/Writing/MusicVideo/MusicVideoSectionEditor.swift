import SwiftUI
import SwiftData

/// Full editor of one section of a clip.
///
/// The section is a scene: what is edited here — its cast, its location, its
/// shots — is the same data the schedule and the budget read.
struct MusicVideoSectionEditor: View {
    @Bindable var scene: StoryScene

    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var modelContext
    @State private var hasTimecode: Bool = false
    @State private var isConfirmingDeletion = false

    private var facet: MusicVideoFacet? { scene.musicFacet }

    private var castCandidates: [Person] {
        scene.project?.people ?? []
    }

    var body: some View {
        NavigationStack {
            Form {
                if let facet {
                    sectionIdentity(facet)
                    timing(facet)
                    writing(facet)
                    staging(facet)
                    cast(facet)
                    shots
                    Section {
                        Button("Supprimer la section", role: .destructive) {
                            isConfirmingDeletion = true
                        }
                        Text("La scène correspondante et ses plans seront supprimés.")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                } else {
                    Text("Cette scène n'a pas encore de structure de clip.")
                        .foregroundStyle(.secondary)
                }
            }
            .creativoFormStyle()
            .navigationTitle(scene.musicSectionName)
            .inlineNavigationTitle()
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Terminé") {
                        commit()
                        dismiss()
                    }
                    .keyboardShortcut(.defaultAction)
                }
            }
            .onAppear {
                hasTimecode = facet?.startTime != nil || facet?.endTime != nil
            }
            .confirmationDialog("Supprimer cette section ?", isPresented: $isConfirmingDeletion) {
                Button("Supprimer", role: .destructive) {
                    MusicVideoService.delete(scene, context: modelContext)
                    dismiss()
                }
                Button("Annuler", role: .cancel) {}
            } message: {
                Text("« \(scene.musicSectionName) » et ses \(scene.shots.count) plan(s) seront supprimés.")
            }
        }
        .macSheetFrame(minWidth: 600, minHeight: 700)
    }

    // MARK: Sections

    private func sectionIdentity(_ facet: MusicVideoFacet) -> some View {
        Section("Section") {
            Picker("Type", selection: Bindable(facet).kind) {
                ForEach(MusicSectionKind.allCases) { kind in
                    Label(kind.displayName, systemImage: kind.symbolName).tag(kind)
                }
            }
            if facet.kind == .custom {
                TextField("Nom de la section", text: Bindable(facet).customName)
            }
            TextField("Titre de la scène", text: $scene.title, prompt: Text("Refrain 1, Rooftop…"))
            Picker("Registre", selection: Bindable(facet).performanceMode) {
                ForEach(MusicPerformanceMode.allCases) { mode in
                    Label(mode.displayName, systemImage: mode.symbolName).tag(mode)
                }
            }
            Text(facet.performanceMode.shortDescription)
                .font(.caption)
                .foregroundStyle(.secondary)
        }
    }

    private func timing(_ facet: MusicVideoFacet) -> some View {
        Section {
            Toggle("Caler sur le morceau", isOn: $hasTimecode)
                .onChange(of: hasTimecode) { _, enabled in
                    if enabled {
                        if facet.startTime == nil { facet.startTime = 0 }
                        if facet.endTime == nil { facet.endTime = facet.startTime ?? 0 }
                    } else {
                        facet.startTime = nil
                        facet.endTime = nil
                    }
                    MusicVideoService.commitEdits(to: facet, context: modelContext)
                }

            if hasTimecode {
                LabeledContent("Début") {
                    DurationField(duration: Binding<TimeInterval>.optionalDuration(Bindable(facet).startTime))
                }
                LabeledContent("Fin") {
                    DurationField(duration: Binding<TimeInterval>.optionalDuration(Bindable(facet).endTime))
                }
                if let duration = facet.duration {
                    LabeledContent("Durée", value: AppFormat.timecode(duration))
                }
            }
        } header: {
            Text("Position dans le morceau")
        } footer: {
            Text("La forme d'onde et les marqueurs audio arriveront avec la phase Music Video Timeline. Les timecodes saisis ici seront repris tels quels.")
                .font(.caption)
        }
    }

    private func writing(_ facet: MusicVideoFacet) -> some View {
        Group {
            Section("Paroles") {
                TextEditor(text: Bindable(facet).lyrics)
                    .frame(minHeight: 140)
                    .font(.body)
            }
            Section("Idée visuelle") {
                TextField(
                    "Ce que l'on voit, comment on le filme",
                    text: Bindable(facet).visualIdea,
                    axis: .vertical
                )
                .lineLimit(3...10)
            }
            Section("Notes de réalisation") {
                TextField("Intentions, références, contraintes", text: $scene.notes, axis: .vertical)
                    .lineLimit(2...8)
            }
        }
    }

    private func staging(_ facet: MusicVideoFacet) -> some View {
        Section("Mise en scène") {
            Picker("Lieu", selection: $scene.location) {
                Text("Aucun").tag(ProductionLocation?.none)
                ForEach(scene.project?.sortedLocations ?? []) { location in
                    Text(location.displayName).tag(ProductionLocation?.some(location))
                }
            }
            TextField("Tenues", text: Bindable(facet).wardrobe, axis: .vertical)
                .lineLimit(1...4)
            TextField("Accessoires", text: Bindable(facet).props, axis: .vertical)
                .lineLimit(1...4)
        }
    }

    private func cast(_ facet: MusicVideoFacet) -> some View {
        Section {
            if castCandidates.isEmpty {
                Text("Ajoutez des personnes au projet dans la section Personnes pour pouvoir les distribuer ici.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            } else {
                ForEach(castCandidates) { person in
                    let isCast = facet.people.contains { $0.id == person.id }
                    Button {
                        if isCast {
                            MusicVideoService.detach(person, from: facet, context: modelContext)
                        } else {
                            MusicVideoService.attach(person, to: facet, context: modelContext)
                        }
                    } label: {
                        HStack(spacing: Spacing.md) {
                            InitialsAvatar(initials: person.initials, tint: person.role.department.tint, size: 28)
                            VStack(alignment: .leading, spacing: 0) {
                                Text(person.displayName)
                                Text(person.role.displayName)
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                            }
                            Spacer(minLength: Spacing.sm)
                            Image(systemName: isCast ? "checkmark.circle.fill" : "circle")
                                .foregroundStyle(isCast ? Color.accentColor : Color.secondary)
                        }
                        .touchTarget()
                    }
                    .buttonStyle(.plain)
                }
            }
        } header: {
            Text("À l'image")
        }
    }

    private var shots: some View {
        Section {
            if scene.shots.isEmpty {
                Text("Aucun plan pour cette section.")
                    .font(.callout)
                    .foregroundStyle(.secondary)
            } else {
                ForEach(scene.sortedShots) { shot in
                    HStack(spacing: Spacing.md) {
                        Text(shot.displayNumber)
                            .font(.caption.monospacedDigit().weight(.semibold))
                            .foregroundStyle(.secondary)
                        VStack(alignment: .leading, spacing: 0) {
                            Text(shot.displayTitle)
                            Text(shot.technicalSummary)
                                .font(.caption)
                                .foregroundStyle(.secondary)
                                .lineLimit(1)
                        }
                        Spacer(minLength: Spacing.sm)
                        Image(systemName: shot.status.symbolName)
                            .foregroundStyle(shot.status.tint)
                    }
                    .touchTarget()
                }
            }
            Button {
                ShotService.create(in: scene, context: modelContext)
            } label: {
                Label("Ajouter un plan", systemImage: "plus")
            }
        } header: {
            HStack {
                Text("Plans associés")
                Spacer()
                let progress = scene.shotProgress
                if progress.total > 0 {
                    Text("\(progress.completed)/\(progress.total) tournés")
                        .monospacedDigit()
                }
            }
            .textCase(nil)
        } footer: {
            Text("Les plans se détaillent dans la section Plans du projet.")
                .font(.caption)
        }
    }

    private func commit() {
        if let facet {
            MusicVideoService.commitEdits(to: facet, context: modelContext)
        }
        SceneService.commitEdits(to: scene, context: modelContext)
    }
}
