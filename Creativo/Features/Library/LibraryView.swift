import SwiftUI
import SwiftData

/// The global library: people, locations and equipment, independent of projects.
struct LibraryView: View {
    @Environment(AppState.self) private var appState

    var body: some View {
        @Bindable var appState = appState

        VStack(spacing: 0) {
            Picker("Section", selection: $appState.librarySection) {
                ForEach(LibrarySection.allCases) { section in
                    Label(section.displayName, systemImage: section.symbolName)
                        .tag(section)
                }
            }
            .pickerStyle(.segmented)
            .labelStyle(.titleAndIcon)
            .padding(.horizontal, Spacing.lg)
            .padding(.vertical, Spacing.md)
            .frame(maxWidth: 520)

            Divider()

            content
        }
        .navigationTitle("Bibliothèque")
        .inlineNavigationTitle()
    }

    @ViewBuilder
    private var content: some View {
        switch appState.librarySection {
        case .people:
            PeopleLibraryView()
        case .locations:
            LocationsLibraryView()
        case .equipment:
            EquipmentLibraryView()
        }
    }
}

#Preview {
    NavigationStack {
        LibraryView()
    }
    .environment(AppState())
    .modelContainer(SampleData.previewContainer)
}
