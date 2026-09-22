import SwiftUI
import SwiftData

/// The crew and cast of a project, drawn from the global library.
struct ProjectPeopleView: View {
    @Bindable var project: Project

    @Environment(\.modelContext) private var modelContext
    @Query private var allPeople: [Person]

    @State private var isPickingFromLibrary = false
    @State private var assignmentBeingEdited: ProjectPersonAssignment?
    @State private var personBeingCreated: Person?

    private var assignments: [ProjectPersonAssignment] { project.sortedPeopleAssignments }

    private var groups: [(department: CrewDepartment, assignments: [ProjectPersonAssignment])] {
        let grouped = Dictionary(grouping: assignments) { $0.effectiveRole.department }
        return CrewDepartment.allCases.compactMap { department in
            guard let items = grouped[department], !items.isEmpty else { return nil }
            return (department, items)
        }
    }

    /// People from the library who are not on this project yet.
    private var availablePeople: [Person] {
        let assigned = Set(assignments.compactMap { $0.person?.id })
        return allPeople
            .filter { !assigned.contains($0.id) }
            .sorted { $0.displayName.localizedCaseInsensitiveCompare($1.displayName) == .orderedAscending }
    }

    private var estimatedCost: Decimal {
        assignments.reduce(Decimal(0)) { $0 + ($1.estimatedCost ?? 0) }
    }

    var body: some View {
        Group {
            if assignments.isEmpty {
                emptyState
            } else {
                list
            }
        }
        .navigationTitle("Personnes")
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
                        createAndAssign()
                    } label: {
                        Label("Créer une personne", systemImage: "person.badge.plus")
                    }
                } label: {
                    Label("Ajouter", systemImage: "plus")
                }
            }
        }
        .sheet(isPresented: $isPickingFromLibrary) {
            LibraryPickerSheet(
                title: "Ajouter au projet",
                emptyMessage: "Créez d'abord des personnes dans la bibliothèque.",
                items: availablePeople,
                searchText: { $0.searchHaystack },
                onSelect: { person in
                    LibraryService.assign(person, to: project, context: modelContext)
                },
                row: { PersonRow(person: $0) }
            )
        }
        .sheet(item: $assignmentBeingEdited) { assignment in
            PersonAssignmentSheet(assignment: assignment)
        }
        .sheet(item: $personBeingCreated) { person in
            PersonEditorSheet(person: person)
        }
    }

    private var list: some View {
        List {
            Section {
                HStack {
                    Text(AppFormat.count(assignments.count, singular: "personne", plural: "personnes", zero: "Aucune personne"))
                    Spacer()
                    if estimatedCost > 0 {
                        Text("Coût estimé : \(AppFormat.currency(estimatedCost))")
                            .monospacedDigit()
                    }
                }
                .font(.caption)
                .foregroundStyle(.secondary)
                .textCase(nil)
            }

            ForEach(groups, id: \.department) { group in
                Section {
                    ForEach(group.assignments) { assignment in
                        Button {
                            assignmentBeingEdited = assignment
                        } label: {
                            row(for: assignment)
                        }
                        .buttonStyle(.plain)
                        .contextMenu {
                            Button("Modifier l'affectation") { assignmentBeingEdited = assignment }
                            Divider()
                            Button("Retirer du projet", role: .destructive) {
                                LibraryService.unassign(assignment, context: modelContext)
                            }
                        }
                        .swipeActions(edge: .trailing) {
                            Button(role: .destructive) {
                                LibraryService.unassign(assignment, context: modelContext)
                            } label: {
                                Label("Retirer", systemImage: "person.badge.minus")
                            }
                        }
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

    @ViewBuilder
    private func row(for assignment: ProjectPersonAssignment) -> some View {
        if let person = assignment.person {
            PersonRow(
                person: person,
                roleOverride: assignment.roleOverride,
                trailingText: assignment.estimatedCost.map { AppFormat.currency($0) }
            )
        } else {
            Text("Personne supprimée")
                .foregroundStyle(.secondary)
        }
    }

    private var emptyState: some View {
        EmptyStateView(
            symbolName: "person.badge.plus",
            title: "Aucune équipe",
            message: "Constituez votre équipe et votre casting à partir de la bibliothèque. Une même personne peut travailler sur plusieurs projets.",
            tint: .indigo
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

                Button("Créer une personne") { createAndAssign() }
                    .buttonStyle(.borderless)
            }
        }
    }

    private func createAndAssign() {
        let person = LibraryService.createPerson(context: modelContext)
        LibraryService.assign(person, to: project, context: modelContext)
        personBeingCreated = person
    }
}

/// Project-specific settings for one person: role, days, rate.
struct PersonAssignmentSheet: View {
    @Bindable var assignment: ProjectPersonAssignment

    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var modelContext
    @State private var isEditingPerson = false

    var body: some View {
        NavigationStack {
            Form {
                Section("Personne") {
                    LabeledContent("Nom", value: assignment.personDisplayName)
                    Button("Modifier la fiche") { isEditingPerson = true }
                        .disabled(assignment.person == nil)
                }

                Section("Sur ce projet") {
                    Picker("Rôle", selection: $assignment.roleOverride) {
                        Text("Rôle par défaut (\(assignment.person?.role.displayName ?? "—"))")
                            .tag(CrewRole?.none)
                        ForEach(CrewRole.allCases) { role in
                            Text(role.displayName).tag(CrewRole?.some(role))
                        }
                    }
                    Stepper(value: $assignment.numberOfDays, in: 1...365) {
                        LabeledContent("Nombre de jours", value: "\(assignment.numberOfDays)")
                    }
                    LabeledContent("Tarif journalier") {
                        TextField(
                            assignment.person?.defaultRate.map { AppFormat.currency($0) } ?? "—",
                            value: Binding<Decimal>.optionalAmount($assignment.dailyRateOverride),
                            format: .currency(code: AppFormat.currencyCode)
                        )
                        .multilineTextAlignment(.trailing)
                        .decimalKeyboard()
                    }
                    if let cost = assignment.estimatedCost {
                        LabeledContent("Coût estimé") {
                            Text(AppFormat.currency(cost))
                                .font(.headline.monospacedDigit())
                        }
                    }
                    TextField("Notes", text: $assignment.notes, axis: .vertical)
                        .lineLimit(2...5)
                }

                Section {
                    Button("Retirer du projet", role: .destructive) {
                        LibraryService.unassign(assignment, context: modelContext)
                        dismiss()
                    }
                    Text("La personne reste dans la bibliothèque.")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }
            .creativoFormStyle()
            .navigationTitle(assignment.personDisplayName)
            .inlineNavigationTitle()
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Terminé") {
                        assignment.project?.touch()
                        LibraryService.commitEdits(context: modelContext)
                        dismiss()
                    }
                    .keyboardShortcut(.defaultAction)
                }
            }
            .sheet(isPresented: $isEditingPerson) {
                if let person = assignment.person {
                    PersonEditorSheet(person: person)
                }
            }
        }
        .macSheetFrame(minWidth: 520, minHeight: 560)
    }
}

#Preview {
    NavigationStack {
        ProjectPeopleView(project: SampleData.previewProject())
    }
    .modelContainer(SampleData.previewContainer)
}
