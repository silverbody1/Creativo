import SwiftUI
import SwiftData

/// The equipment library, shared by every project.
struct EquipmentLibraryView: View {
    @Environment(\.modelContext) private var modelContext
    @Query private var items: [EquipmentItem]

    @State private var query = ""
    @State private var itemBeingEdited: EquipmentItem?

    private var sortedItems: [EquipmentItem] {
        items.sorted { lhs, rhs in
            if lhs.category != rhs.category { return lhs.category.sortIndex < rhs.category.sortIndex }
            return lhs.displayName.localizedCaseInsensitiveCompare(rhs.displayName) == .orderedAscending
        }
    }

    private var visibleItems: [EquipmentItem] {
        LibraryService.filter(sortedItems, query: query)
    }

    private var groups: [(category: EquipmentCategory, items: [EquipmentItem])] {
        let grouped = Dictionary(grouping: visibleItems, by: \.category)
        return EquipmentCategory.allCases.compactMap { category in
            guard let categoryItems = grouped[category], !categoryItems.isEmpty else { return nil }
            return (category, categoryItems)
        }
    }

    var body: some View {
        Group {
            if items.isEmpty {
                emptyState
            } else if visibleItems.isEmpty {
                EmptyStateView(
                    symbolName: "magnifyingglass",
                    title: "Aucun résultat",
                    message: "Aucun matériel ne correspond à « \(query) »."
                )
            } else {
                List {
                    ForEach(groups, id: \.category) { group in
                        Section {
                            ForEach(group.items) { item in
                                Button {
                                    itemBeingEdited = item
                                } label: {
                                    EquipmentRow(item: item)
                                }
                                .buttonStyle(.plain)
                            }
                        } header: {
                            HStack(spacing: Spacing.sm) {
                                Image(systemName: group.category.symbolName)
                                    .foregroundStyle(group.category.tint)
                                Text(group.category.displayName)
                                    .font(.caption.weight(.semibold))
                            }
                            .textCase(nil)
                        }
                    }
                }
            }
        }
        .searchable(text: $query, prompt: "Rechercher du matériel")
        .toolbar {
            ToolbarItem(placement: .primaryAction) {
                Button {
                    itemBeingEdited = LibraryService.createEquipment(in: modelContext)
                } label: {
                    Label("Nouveau matériel", systemImage: "plus")
                }
            }
        }
        .sheet(item: $itemBeingEdited) { item in
            EquipmentEditorSheet(item: item)
        }
    }

    private var emptyState: some View {
        EmptyStateView(
            symbolName: "camera",
            title: "Aucun matériel",
            message: "Caméras, optiques, lumière, son : listez ce que vous possédez et ce que vous louez, avec leurs tarifs.",
            tint: .teal
        ) {
            Button {
                itemBeingEdited = LibraryService.createEquipment(in: modelContext)
            } label: {
                Label("Ajouter du matériel", systemImage: "plus")
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
        EquipmentLibraryView()
    }
    .modelContainer(SampleData.previewContainer)
}
