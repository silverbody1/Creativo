import Foundation
import Observation

/// Navigation and presentation state shared by the whole app.
///
/// Deliberately holds *no* domain logic and *no* model context: it only knows
/// which screen is on screen. Everything persistent lives in SwiftData.
@Observable
final class AppState {
    /// Selected section of the app shell.
    var sidebarSelection: SidebarDestination? = .home

    /// Project currently opened in the workspace. `nil` means the shell is showing.
    var openedProject: Project?

    /// Section selected inside the workspace.
    var workspaceSection: WorkspaceSection = .overview

    /// Section selected inside the global library.
    var librarySection: LibrarySection = .people

    /// Drives the "Créer un projet" sheet from anywhere, including the ⌘N menu command.
    var isPresentingNewProject = false

    /// Writing takes over the whole window, hiding both sidebars.
    var isWritingFocusMode = false

    init() {}

    // MARK: Intents

    func open(_ project: Project) {
        workspaceSection = .overview
        isWritingFocusMode = false
        openedProject = project
    }

    /// Opens a project straight into its writing surface.
    func openForWriting(_ project: Project) {
        openedProject = project
        workspaceSection = .writing
    }

    /// Leaves the workspace. Always call this *before* deleting the opened
    /// project so no view is left holding a deleted model.
    func closeProject() {
        isWritingFocusMode = false
        openedProject = nil
    }

    func closeIfOpened(_ project: Project) {
        if openedProject?.id == project.id {
            closeProject()
        }
    }

    func presentNewProject() {
        closeProject()
        isPresentingNewProject = true
    }

    /// ⌘F: jump to the project list, which is the searchable surface of the shell.
    func focusSearch() {
        closeProject()
        sidebarSelection = .allProjects
    }

    func showSettings() {
        closeProject()
        sidebarSelection = .settings
    }
}
