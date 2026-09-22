import SwiftUI
import SwiftData

/// The app shell: main sidebar plus its detail column.
struct MainShellView: View {
    @Environment(AppState.self) private var appState
    @State private var columnVisibility: NavigationSplitViewVisibility = .all

    var body: some View {
        @Bindable var appState = appState

        NavigationSplitView(columnVisibility: $columnVisibility) {
            List(selection: $appState.sidebarSelection) {
                Section {
                    ForEach(SidebarDestination.primaryGroup) { destination in
                        row(for: destination)
                    }
                }
                Section {
                    ForEach(SidebarDestination.secondaryGroup) { destination in
                        row(for: destination)
                    }
                }
            }
            .navigationTitle("Creativo")
            .navigationSplitViewColumnWidth(
                min: LayoutMetrics.sidebarMinWidth,
                ideal: LayoutMetrics.sidebarIdealWidth,
                max: LayoutMetrics.sidebarMaxWidth
            )
            .safeAreaInset(edge: .bottom) {
                Button {
                    appState.presentNewProject()
                } label: {
                    Label("Nouveau projet", systemImage: "plus")
                        .frame(maxWidth: .infinity)
                        .touchTarget()
                }
                .buttonStyle(.borderedProminent)
                .padding(Spacing.md)
            }
        } detail: {
            NavigationStack {
                detail
            }
            .id(appState.sidebarSelection)
        }
        .navigationSplitViewStyle(.balanced)
    }

    private func row(for destination: SidebarDestination) -> some View {
        Label(destination.displayName, systemImage: destination.symbolName)
            .touchTarget(LayoutMetrics.minimumTouchTarget - 8)
            .tag(destination)
    }

    @ViewBuilder
    private var detail: some View {
        switch appState.sidebarSelection ?? .home {
        case .home:
            HomeView()
        case .allProjects:
            ProjectsListView(scope: .all)
        case .favorites:
            ProjectsListView(scope: .favorites)
        case .library:
            LibraryView()
        case .settings:
            SettingsView()
        }
    }
}

#Preview {
    MainShellView()
        .environment(AppState())
        .modelContainer(SampleData.previewContainer)
}
