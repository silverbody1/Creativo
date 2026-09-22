import SwiftUI

/// Generic "pick something from the library" sheet.
///
/// One implementation for people, locations and equipment: the caller supplies
/// the candidates, how to search them and how to draw a row.
struct LibraryPickerSheet<Item: Identifiable & Hashable, Row: View>: View {
    let title: String
    let emptyMessage: String
    let items: [Item]
    let searchText: (Item) -> String
    let onSelect: (Item) -> Void
    @ViewBuilder var row: (Item) -> Row

    @Environment(\.dismiss) private var dismiss
    @State private var query = ""

    private var visibleItems: [Item] {
        guard !query.isBlank else { return items }
        return items.filter { searchText($0).matches(query) }
    }

    var body: some View {
        NavigationStack {
            Group {
                if items.isEmpty {
                    EmptyStateView(
                        symbolName: "books.vertical",
                        title: "Bibliothèque vide",
                        message: emptyMessage
                    )
                } else if visibleItems.isEmpty {
                    EmptyStateView(
                        symbolName: "magnifyingglass",
                        title: "Aucun résultat",
                        message: "Rien ne correspond à « \(query) »."
                    )
                } else {
                    List(visibleItems) { item in
                        Button {
                            onSelect(item)
                            dismiss()
                        } label: {
                            row(item)
                        }
                        .buttonStyle(.plain)
                    }
                }
            }
            .navigationTitle(title)
            .inlineNavigationTitle()
            .searchable(text: $query, prompt: "Rechercher")
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Fermer") { dismiss() }
                }
            }
        }
        .macSheetFrame(minWidth: 480, minHeight: 520)
    }
}
