import SwiftUI
import SwiftData

/// The locations attached to a project, drawn from the global library.
struct ProjectLocationsView: View {
    @Bindable var project: Project

    @Environment(\.modelContext) private var modelContext
    @Query private var allLocations: [ProductionLocation]

    @State private var isPickingFromLibrary = false
    @State private var locationBeingEdited: ProductionLocation?
    @State private var locationPendingDetach: ProductionLocation?

    private var locations: [ProductionLocation] { project.sortedLocations }

    private var availableLocations: [ProductionLocation] {
        let attached = Set(locations.map(\.id))
        return allLocations
            .filter { !attached.contains($0.id) }
            .sorted { $0.displayName.localizedCaseInsensitiveCompare($1.displayName) == .orderedAscending }
    }

    private func sceneCount(for location: ProductionLocation) -> Int {
        project.scenes.filter { $0.location?.id == location.id }.count
    }

    var body: some View {
        Group {
            if locations.isEmpty {
                emptyState
            } else {
                list
            }
        }
        .navigationTitle("Lieux")
        .inlineNavigationTitle()
        .toolbar {
            ToolbarItem(placement: .primaryAction) {
                Menu {
                    Button {
                        isPickingFromLibrary = true
                    } label: {
                        Label("Depuis la bibliothèque", systemImage: "books.vertical")
                    }
                    Button {
                        createAndAttach()
                    } label: {
                        Label("Créer un lieu", systemImage: "mappin.and.ellipse")
                    }
                } label: {
                    Label("Ajouter", systemImage: "plus")
                }
            }
        }
        .sheet(isPresented: $isPickingFromLibrary) {
            LibraryPickerSheet(
                title: "Ajouter au projet",
                emptyMessage: "Créez d'abord des lieux dans la bibliothèque.",
                items: availableLocations,
                searchText: { $0.searchHaystack },
                onSelect: { location in
                    LibraryService.attach(location, to: project, in: modelContext)
                },
                row: { LocationRow(location: $0) }
            )
        }
        .sheet(item: $locationBeingEdited) { location in
            LocationEditorSheet(location: location)
        }
        .confirmationDialog(
            "Retirer ce lieu du projet ?",
            isPresented: detachBinding,
            presenting: locationPendingDetach
        ) { location in
            Button("Retirer", role: .destructive) {
                LibraryService.detach(location, from: project, in: modelContext)
                locationPendingDetach = nil
            }
            Button("Annuler", role: .cancel) { locationPendingDetach = nil }
        } message: { location in
            Text("Les scènes qui utilisent « \(location.displayName) » perdront leur lieu. Le lieu reste dans la bibliothèque.")
        }
    }

    private var list: some View {
        List {
            Section {
                Text(AppFormat.count(locations.count, singular: "lieu", plural: "lieux", zero: "Aucun lieu"))
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .textCase(nil)
            }

            ForEach(locations) { location in
                Button {
                    locationBeingEdited = location
                } label: {
                    LocationRow(
                        location: location,
                        trailingText: sceneCount(for: location) > 0
                            ? AppFormat.count(sceneCount(for: location), singular: "scène", plural: "scènes", zero: "")
                            : nil
                    )
                }
                .buttonStyle(.plain)
                .contextMenu {
                    Button("Modifier la fiche") { locationBeingEdited = location }
                    Divider()
                    Button("Retirer du projet", role: .destructive) { locationPendingDetach = location }
                }
                .swipeActions(edge: .trailing) {
                    Button(role: .destructive) {
                        locationPendingDetach = location
                    } label: {
                        Label("Retirer", systemImage: "minus.circle")
                    }
                }
            }
        }
    }

    private var emptyState: some View {
        EmptyStateView(
            symbolName: "mappin.and.ellipse",
            title: "Aucun lieu",
            message: "Rattachez vos lieux de tournage au projet pour pouvoir les affecter à vos scènes.",
            tint: .pink
        ) {
            VStack(spacing: Spacing.sm) {
                Button {
                    isPickingFromLibrary = true
                } label: {
                    Label("Choisir dans la bibliothèque", systemImage: "books.vertical")
                        .touchTarget()
                        .padding(.horizontal, Spacing.sm)
                }
                .buttonStyle(.borderedProminent)
                .controlSize(.large)

                Button("Créer un lieu") { createAndAttach() }
                    .buttonStyle(.borderless)
            }
        }
    }

    private var detachBinding: Binding<Bool> {
        Binding(
            get: { locationPendingDetach != nil },
            set: { if !$0 { locationPendingDetach = nil } }
        )
    }

    private func createAndAttach() {
        let location = LibraryService.createLocation(in: modelContext)
        LibraryService.attach(location, to: project, in: modelContext)
        locationBeingEdited = location
    }
}

#Preview {
    NavigationStack {
        ProjectLocationsView(project: SampleData.previewProject())
    }
    .modelContainer(SampleData.previewContainer)
}
