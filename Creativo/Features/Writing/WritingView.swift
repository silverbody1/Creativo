import SwiftUI
import SwiftData

/// The Writing section of a project.
///
/// Three surfaces, one section: the editor that appears follows the project
/// type, and the user can override it. Switching mode never destroys anything —
/// a screenplay, a video outline and a clip structure can coexist on the same
/// project — which is what will let a project carry several modes at once in a
/// later phase without touching the schema.
struct WritingView: View {
    @Bindable var project: Project
    var isFocusMode: Bool = false

    @Environment(\.modelContext) private var modelContext

    var body: some View {
        editor
            .toolbar {
                ToolbarItem(placement: .automatic) {
                    modeMenu
                }
            }
    }

    @ViewBuilder
    private var editor: some View {
        switch project.writingMode {
        case .screenplay:
            ScreenplayEditorView(project: project, isFocusMode: isFocusMode)
        case .youtube:
            YouTubeScriptView(project: project, isFocusMode: isFocusMode)
        case .musicVideo:
            MusicVideoWritingView(project: project, isFocusMode: isFocusMode)
        }
    }

    private var modeMenu: some View {
        Menu {
            Section("Mode d'écriture") {
                ForEach(WritingMode.allCases) { mode in
                    Button {
                        select(mode)
                    } label: {
                        Label(
                            mode.displayName,
                            systemImage: project.writingMode == mode ? "checkmark" : mode.symbolName
                        )
                    }
                }
            }

            if project.writingModeOverride != nil {
                Divider()
                Button("Suivre le type de projet (\(project.type.defaultWritingMode.displayName))") {
                    select(nil)
                }
            }

            Divider()
            Text(project.writingMode.shortDescription)
        } label: {
            Label(project.writingMode.displayName, systemImage: project.writingMode.symbolName)
        }
        .help("Changer de mode d'écriture. Rien n'est supprimé.")
    }

    private func select(_ mode: WritingMode?) {
        project.writingModeOverride = mode
        ProjectService.commitEdits(to: project, context: modelContext)
    }
}

/// Full-window writing, without the project sidebar.
///
/// A takeover rather than an overlay, the same pattern the workspace itself
/// uses, so focus mode behaves identically on macOS and iPadOS.
struct WritingFocusView: View {
    @Bindable var project: Project

    @Environment(AppState.self) private var appState

    var body: some View {
        NavigationStack {
            WritingView(project: project, isFocusMode: true)
                .toolbar {
                    ToolbarItem(placement: .cancellationAction) {
                        Button {
                            appState.isWritingFocusMode = false
                        } label: {
                            Label("Quitter le mode focus", systemImage: "chevron.left")
                        }
                        .keyboardShortcut(.escape, modifiers: [])
                    }
                }
        }
    }
}

#Preview("Scénario") {
    NavigationStack {
        WritingView(project: SampleData.previewProject(type: .film))
    }
    .environment(AppState())
    .modelContainer(SampleData.previewContainer)
}

#Preview("Clip") {
    NavigationStack {
        WritingView(project: SampleData.previewProject())
    }
    .environment(AppState())
    .modelContainer(SampleData.previewContainer)
}
