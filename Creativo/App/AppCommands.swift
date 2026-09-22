import SwiftUI
import SwiftData

/// Menu bar commands and keyboard shortcuts.
///
/// Declared once and shared by macOS and iPadOS: on iPad these become the
/// hardware-keyboard shortcuts and the discoverability HUD.
struct AppCommands: Commands {
    let appState: AppState
    let container: ModelContainer

    var body: some Commands {
        CommandGroup(replacing: .newItem) {
            Button("Nouveau projet") {
                appState.presentNewProject()
            }
            .keyboardShortcut("n", modifiers: .command)
        }

        CommandGroup(replacing: .saveItem) {
            Button("Enregistrer") {
                PersistenceActions.save(container.mainContext)
            }
            .keyboardShortcut("s", modifiers: .command)
        }

        CommandMenu("Aller à") {
            Button("Accueil") { go(.home) }
                .keyboardShortcut("1", modifiers: .command)
            Button("Tous les projets") { go(.allProjects) }
                .keyboardShortcut("2", modifiers: .command)
            Button("Favoris") { go(.favorites) }
                .keyboardShortcut("3", modifiers: .command)
            Button("Bibliothèque") { go(.library) }
                .keyboardShortcut("4", modifiers: .command)

            Divider()

            Button("Rechercher un projet") {
                appState.focusSearch()
            }
            .keyboardShortcut("f", modifiers: .command)

            Divider()

            Button("Fermer le projet") {
                appState.closeProject()
            }
            .keyboardShortcut("w", modifiers: [.command, .shift])
            .disabled(appState.openedProject == nil)
        }

        #if !os(macOS)
        // On macOS the Settings scene already owns ⌘, ; on iPadOS it does not exist.
        CommandGroup(replacing: .appSettings) {
            Button("Réglages…") {
                appState.showSettings()
            }
            .keyboardShortcut(",", modifiers: .command)
        }
        #endif
    }

    private func go(_ destination: SidebarDestination) {
        appState.closeProject()
        appState.sidebarSelection = destination
    }
}
