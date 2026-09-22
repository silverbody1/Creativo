import SwiftUI
import SwiftData

/// The people library: everyone the user has ever worked with.
struct PeopleLibraryView: View {
    @Environment(\.modelContext) private var modelContext
    @Query private var people: [Person]

    @State private var query = ""
    @State private var personBeingEdited: Person?

    private var sortedPeople: [Person] {
        people.sorted { $0.displayName.localizedCaseInsensitiveCompare($1.displayName) == .orderedAscending }
    }

    private var visiblePeople: [Person] {
        LibraryService.filter(sortedPeople, query: query)
    }

    private var groups: [(department: CrewDepartment, people: [Person])] {
        let grouped = Dictionary(grouping: visiblePeople) { $0.role.department }
        return CrewDepartment.allCases.compactMap { department in
            guard let members = grouped[department], !members.isEmpty else { return nil }
            return (department, members)
        }
    }

    var body: some View {
        Group {
            if people.isEmpty {
                emptyState
            } else if visiblePeople.isEmpty {
                EmptyStateView(
                    symbolName: "magnifyingglass",
                    title: "Aucun résultat",
                    message: "Personne ne correspond à « \(query) »."
                )
            } else {
                List {
                    ForEach(groups, id: \.department) { group in
                        Section {
                            ForEach(group.people) { person in
                                Button {
                                    personBeingEdited = person
                                } label: {
                                    PersonRow(
                                        person: person,
                                        trailingText: person.projectCount > 0
                                            ? AppFormat.count(person.projectCount, singular: "projet", plural: "projets", zero: "")
                                            : nil
                                    )
                                }
                                .buttonStyle(.plain)
                            }
                        } header: {
                            HStack(spacing: Spacing.sm) {
                                Image(systemName: group.department.symbolName)
                                    .foregroundStyle(group.department.tint)
                                Text(group.department.displayName)
                                    .font(.caption.weight(.semibold))
                            }
                            .textCase(nil)
                        }
                    }
                }
            }
        }
        .searchable(text: $query, prompt: "Rechercher une personne")
        .toolbar {
            ToolbarItem(placement: .primaryAction) {
                Button {
                    personBeingEdited = LibraryService.createPerson(in: modelContext)
                } label: {
                    Label("Nouvelle personne", systemImage: "plus")
                }
            }
        }
        .sheet(item: $personBeingEdited) { person in
            PersonEditorSheet(person: person)
        }
    }

    private var emptyState: some View {
        EmptyStateView(
            symbolName: "person.2",
            title: "Aucune personne",
            message: "Réalisateurs, chefs opérateurs, artistes, danseurs : votre carnet d'adresses de production, réutilisable sur tous vos projets.",
            tint: .indigo
        ) {
            Button {
                personBeingEdited = LibraryService.createPerson(in: modelContext)
            } label: {
                Label("Ajouter une personne", systemImage: "plus")
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
        PeopleLibraryView()
    }
    .modelContainer(SampleData.previewContainer)
}
