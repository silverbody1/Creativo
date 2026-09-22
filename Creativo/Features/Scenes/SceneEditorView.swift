import SwiftUI
import SwiftData

/// Simple scene editor.
///
/// Deliberately not a screenplay editor: phase 1 gives a clean, fast form for
/// the fields the rest of the app depends on. The professional writing surface
/// is its own phase and will replace the "Contenu" section only.
struct SceneEditorView: View {
    @Bindable var scene: StoryScene

    @Environment(\.modelContext) private var modelContext
    @Environment(AppState.self) private var appState
    @State private var shotBeingEdited: Shot?

    private var availableLocations: [ProductionLocation] {
        scene.project?.sortedLocations ?? []
    }

    /// Any edit to these fields stamps the scene and its project as modified.
    private var editSignature: String {
        [
            scene.sceneNumber,
            scene.title,
            scene.synopsis,
            scene.content,
            scene.notes,
            scene.environment.rawValue,
            scene.timeOfDay.rawValue,
            scene.status.rawValue,
            String(scene.estimatedDuration),
            scene.location?.id.uuidString ?? ""
        ].joined(separator: "|")
    }

    var body: some View {
        Form {
            Section {
                TextField("Numéro", text: $scene.sceneNumber)
                    .rawTextField()
                TextField("Titre", text: $scene.title, prompt: Text("Intro, Refrain 1, Séquence finale…"))
            } header: {
                Text("Scène")
            } footer: {
                Text(scene.slugline)
                    .font(.caption.monospaced())
                    .foregroundStyle(.secondary)
            }

            Section("Contexte") {
                Picker("Intérieur / Extérieur", selection: $scene.environment) {
                    ForEach(SceneEnvironment.allCases) { value in
                        Text(value.displayName).tag(value)
                    }
                }
                Picker("Moment", selection: $scene.timeOfDay) {
                    ForEach(TimeOfDay.allCases) { value in
                        Label(value.displayName, systemImage: value.symbolName).tag(value)
                    }
                }
                Picker("Lieu", selection: $scene.location) {
                    Text("Aucun").tag(ProductionLocation?.none)
                    ForEach(availableLocations) { location in
                        Text(location.displayName).tag(ProductionLocation?.some(location))
                    }
                }
                if availableLocations.isEmpty {
                    Text("Rattachez des lieux au projet dans la section Lieux pour pouvoir les choisir ici.")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                LabeledContent("Durée estimée") {
                    DurationField(duration: $scene.estimatedDuration)
                }
                Picker("Statut", selection: $scene.status) {
                    ForEach(SceneStatus.allCases) { status in
                        Label(status.displayName, systemImage: status.symbolName).tag(status)
                    }
                }
            }

            Section("Synopsis") {
                TextField("Ce qui se passe, en une ou deux phrases", text: $scene.synopsis, axis: .vertical)
                    .lineLimit(2...6)
            }

            contentSection

            Section("Notes") {
                TextField("Notes de préparation", text: $scene.notes, axis: .vertical)
                    .lineLimit(2...6)
            }

            shotsSection
        }
        .creativoFormStyle()
        .navigationTitle("Scène \(scene.displayNumber)")
        .inlineNavigationTitle()
        .onChange(of: editSignature) { _, _ in
            scene.touch()
        }
        .sheet(item: $shotBeingEdited) { shot in
            ShotEditorSheet(shot: shot)
        }
    }

    /// A scene written in the screenplay editor is shown read-only here, so the
    /// two surfaces can never disagree about the same text.
    @ViewBuilder
    private var contentSection: some View {
        if scene.hasScreenplay {
            Section {
                Text(scene.content)
                    .font(.system(.callout, design: .monospaced))
                    .foregroundStyle(.secondary)
                    .frame(maxWidth: .infinity, alignment: .leading)
                Button {
                    appState.workspaceSection = .writing
                } label: {
                    Label("Ouvrir dans l'éditeur de scénario", systemImage: "doc.text")
                }
            } header: {
                HStack {
                    Text("Contenu")
                    Spacer()
                    Text(ScreenplayFormatter.pageCountText(for: [scene]))
                        .monospacedDigit()
                }
                .textCase(nil)
            } footer: {
                Text("Ce texte est écrit dans la section Écriture. Il se met à jour automatiquement.")
                    .font(.caption)
            }
        } else {
            Section {
                TextEditor(text: $scene.content)
                    .frame(minHeight: 180)
                    .font(.body)
                Button {
                    appState.workspaceSection = .writing
                } label: {
                    Label("Écrire dans l'éditeur de scénario", systemImage: "doc.text")
                }
            } header: {
                Text("Contenu")
            }
        }
    }

    private var shotsSection: some View {
        Section {
            if scene.shots.isEmpty {
                Text("Aucun plan pour cette scène.")
                    .font(.callout)
                    .foregroundStyle(.secondary)
            } else {
                ForEach(scene.sortedShots) { shot in
                    Button {
                        shotBeingEdited = shot
                    } label: {
                        ShotRow(shot: shot)
                    }
                    .buttonStyle(.plain)
                }
            }
            Button {
                shotBeingEdited = ShotService.create(in: scene, context: modelContext)
            } label: {
                Label("Ajouter un plan", systemImage: "plus")
            }
        } header: {
            HStack {
                Text("Plans")
                Spacer()
                let progress = scene.shotProgress
                if progress.total > 0 {
                    Text("\(progress.completed)/\(progress.total) tournés")
                        .monospacedDigit()
                }
            }
            .textCase(nil)
        }
    }
}

#Preview {
    NavigationStack {
        SceneEditorView(scene: SampleData.previewScene())
    }
    .environment(AppState())
    .modelContainer(SampleData.previewContainer)
}
