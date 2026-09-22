import SwiftUI
import SwiftData

/// A project opened for work: internal sidebar plus the selected section.
struct ProjectWorkspaceView: View {
    @Bindable var project: Project

    @Environment(AppState.self) private var appState
    @Environment(\.modelContext) private var modelContext
    @State private var columnVisibility: NavigationSplitViewVisibility = .all
    @State private var isPresentingSettings = false

    var body: some View {
        @Bindable var appState = appState

        NavigationSplitView(columnVisibility: $columnVisibility) {
            VStack(spacing: 0) {
                header
                Divider()
                List(selection: $appState.workspaceSection) {
                    Section("Création") {
                        ForEach(WorkspaceSection.creationGroup) { sidebarRow($0) }
                    }
                    Section("Production") {
                        ForEach(WorkspaceSection.productionGroup) { sidebarRow($0) }
                    }
                    Section("Organisation") {
                        ForEach(WorkspaceSection.organisationGroup) { sidebarRow($0) }
                    }
                }
            }
            .navigationTitle(project.displayName)
            .navigationSplitViewColumnWidth(
                min: LayoutMetrics.sidebarMinWidth,
                ideal: LayoutMetrics.sidebarIdealWidth,
                max: LayoutMetrics.sidebarMaxWidth
            )
        } detail: {
            // A fresh stack per section: switching section must not leave a
            // pushed editor from the previous one on screen.
            NavigationStack {
                sectionView
            }
            .id(appState.workspaceSection)
        }
        .navigationSplitViewStyle(.balanced)
        .sheet(isPresented: $isPresentingSettings) {
            ProjectSettingsSheet(project: project)
        }
    }

    // MARK: Sidebar

    private var header: some View {
        VStack(alignment: .leading, spacing: Spacing.md) {
            Button {
                appState.closeProject()
            } label: {
                Label("Projets", systemImage: "chevron.left")
                    .font(.callout)
            }
            .buttonStyle(.borderless)
            .keyboardShortcut("[", modifiers: .command)

            HStack(alignment: .top, spacing: Spacing.sm) {
                VStack(alignment: .leading, spacing: Spacing.xs) {
                    Text(project.displayName)
                        .font(.headline)
                        .lineLimit(2)
                    HStack(spacing: Spacing.xs) {
                        Chip(text: project.type.displayName, tint: project.type.tint)
                        Chip(text: project.status.displayName, tint: project.status.tint)
                    }
                }
                Spacer(minLength: 0)
                Button {
                    isPresentingSettings = true
                } label: {
                    Image(systemName: "slider.horizontal.3")
                }
                .buttonStyle(.borderless)
                .help("Réglages du projet")
                .accessibilityLabel("Réglages du projet")
            }
        }
        .padding(Spacing.md)
    }

    private func sidebarRow(_ section: WorkspaceSection) -> some View {
        HStack(spacing: Spacing.sm) {
            Label(section.displayName, systemImage: section.symbolName)
            Spacer(minLength: 0)
            if let badge = badge(for: section) {
                Text(badge)
                    .font(.caption.monospacedDigit())
                    .foregroundStyle(.secondary)
            }
        }
        .touchTarget(LayoutMetrics.minimumTouchTarget - 8)
        .tag(section)
    }

    /// Counts shown on the right of the sidebar rows, so the user sees where
    /// the work already is without opening every section.
    private func badge(for section: WorkspaceSection) -> String? {
        let value: Int
        switch section {
        case .scenes: value = project.scenes.count
        case .shots: value = project.allShots.count
        case .locations: value = project.locations.count
        case .people: value = project.peopleAssignments.count
        case .equipment: value = project.equipmentAssignments.count
        case .budget: value = project.budgetLines.count
        case .schedule: value = project.shootDays.count
        case .documents: value = project.references.count
        case .overview, .writing, .board: return nil
        }
        return value > 0 ? "\(value)" : nil
    }

    // MARK: Detail

    @ViewBuilder
    private var sectionView: some View {
        switch appState.workspaceSection {
        case .overview:
            ProjectOverviewView(project: project)
        case .scenes:
            SceneListView(project: project)
        case .shots:
            ShotsView(project: project)
        case .locations:
            ProjectLocationsView(project: project)
        case .people:
            ProjectPeopleView(project: project)
        case .equipment:
            ProjectEquipmentView(project: project)
        case .budget:
            BudgetView(project: project)
        case .schedule:
            ScheduleView(project: project)
        case .writing, .board, .documents:
            ComingSoonSectionView(section: appState.workspaceSection, project: project)
        }
    }
}

#Preview {
    ProjectWorkspaceView(project: SampleData.previewProject())
        .environment(AppState())
        .modelContainer(SampleData.previewContainer)
}
