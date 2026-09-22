import SwiftUI
import SwiftData

/// The locations library, shared by every project.
struct LocationsLibraryView: View {
    @Environment(\.modelContext) private var modelContext
    @Query private var locations: [ProductionLocation]

    @State private var query = ""
    @State private var locationBeingEdited: ProductionLocation?

    private var sortedLocations: [ProductionLocation] {
        locations.sorted { $0.displayName.localizedCaseInsensitiveCompare($1.displayName) == .orderedAscending }
    }

    private var visibleLocations: [ProductionLocation] {
        LibraryService.filter(sortedLocations, query: query)
    }

    var body: some View {
        Group {
            if locations.isEmpty {
                emptyState
            } else if visibleLocations.isEmpty {
                EmptyStateView(
                    symbolName: "magnifyingglass",
                    title: "Aucun résultat",
                    message: "Aucun lieu ne correspond à « \(query) »."
                )
            } else {
                List(visibleLocations) { location in
                    Button {
                        locationBeingEdited = location
                    } label: {
                        LocationRow(
                            location: location,
                            trailingText: location.projects.isEmpty
                                ? nil
                                : AppFormat.count(location.projects.count, singular: "projet", plural: "projets", zero: "")
                        )
                    }
                    .buttonStyle(.plain)
                }
            }
        }
        .searchable(text: $query, prompt: "Rechercher un lieu")
        .toolbar {
            ToolbarItem(placement: .primaryAction) {
                Button {
                    locationBeingEdited = LibraryService.createLocation(in: modelContext)
                } label: {
                    Label("Nouveau lieu", systemImage: "plus")
                }
            }
        }
        .sheet(item: $locationBeingEdited) { location in
            LocationEditorSheet(location: location)
        }
    }

    private var emptyState: some View {
        EmptyStateView(
            symbolName: "mappin.and.ellipse",
            title: "Aucun lieu",
            message: "Studios, appartements, extérieurs : gardez vos repérages, leurs contacts et leurs contraintes au même endroit.",
            tint: .pink
        ) {
            Button {
                locationBeingEdited = LibraryService.createLocation(in: modelContext)
            } label: {
                Label("Ajouter un lieu", systemImage: "plus")
                    .touchTarget()
                    .padding(.horizontal, Spacing.sm)
            }
            .buttonStyle(.borderedProminent)
            .controlSize(.large)
        }
    }
}

#Preview {
    NavigationStack {
        LocationsLibraryView()
    }
    .modelContainer(SampleData.previewContainer)
}
