import SwiftUI
import SwiftData

@main
struct CreativoApp: App {
    @State private var appState = AppState()
    private let container: ModelContainer

    init() {
        container = PersistenceController.makeAppContainer()
    }

    var body: some Scene {
        mainWindow
        #if os(macOS)
        settingsWindow
        #endif
    }

    private var rootContent: some View {
        RootView()
            .environment(appState)
    }

    private var mainWindow: some Scene {
        #if os(macOS)
        return WindowGroup {
            rootContent
        }
        .modelContainer(container)
        .commands { AppCommands(appState: appState, container: container) }
        .defaultSize(width: 1280, height: 840)
        #else
        return WindowGroup {
            rootContent
        }
        .modelContainer(container)
        .commands { AppCommands(appState: appState, container: container) }
        #endif
    }

    #if os(macOS)
    private var settingsWindow: some Scene {
        Settings {
            SettingsView()
                .environment(appState)
                .modelContainer(container)
                .frame(minWidth: 520, minHeight: 420)
        }
    }
    #endif
}
