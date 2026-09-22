import SwiftUI
import SwiftData

/// Switches between the app shell and an opened project workspace.
///
/// Opening a project is a full takeover rather than a push inside the detail
/// column: it gives the workspace a real sidebar of its own on both platforms,
/// which is exactly what a project needs, and it keeps each level a plain
/// `NavigationSplitView` instead of a nested one.
struct RootView: View {
    @Environment(AppState.self) private var appState
    @AppStorage("appAppearance") private var appearance: AppAppearance = .system

    var body: some View {
        @Bindable var appState = appState

        Group {
            if let project = appState.openedProject, appState.isWritingFocusMode {
                WritingFocusView(project: project)
                    .transition(.opacity)
            } else if let project = appState.openedProject {
                ProjectWorkspaceView(project: project)
                    .transition(.opacity)
            } else {
                MainShellView()
                    .transition(.opacity)
            }
        }
        .animation(.smooth(duration: 0.22), value: appState.openedProject?.id)
        .animation(.smooth(duration: 0.22), value: appState.isWritingFocusMode)
        .sheet(isPresented: $appState.isPresentingNewProject) {
            NewProjectSheet()
        }
        .preferredColorScheme(appearance.colorScheme)
    }
}

#Preview {
    RootView()
        .environment(AppState())
        .modelContainer(SampleData.previewContainer)
}
