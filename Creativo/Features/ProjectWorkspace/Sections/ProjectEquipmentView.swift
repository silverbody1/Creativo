import SwiftUI
import SwiftData

/// The gear list of a project, drawn from the global library.
struct ProjectEquipmentView: View {
    @Bindable var project: Project

    @Environment(\.modelContext) private var modelContext
    @Query private var allEquipment: [EquipmentItem]

    @State private var isPickingFromLibrary = false
    @State private var assignmentBeingEdited: ProjectEquipmentAssignment?
    @State private var itemBeingCreated: EquipmentItem?

    private var assignments: [ProjectEquipmentAssignment] { project.sortedEquipmentAssignments }

    private var groups: [(category: EquipmentCategory, assignments: [ProjectEquipmentAssignment])] {
        let grouped = Dictionary(grouping: assignments) { $0.equipment?.category ?? .other }
        return EquipmentCategory.allCases.compactMap { category in
            guard let items = grouped[category], !items.isEmpty else { return nil }
            return (category, items)
        }
    }

    private var availableEquipment: [EquipmentItem] {
        let assigned = Set(assignments.compactMap { $0.equipment?.id })
        return allEquipment
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
        .navigationTitle("Matériel")
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
                        Label("Créer du matériel", systemImage: "camera.badge.ellipsis")
                    }
                } label: {
                    Label("Ajouter", systemImage: "plus")
                }
            }
        }
        .sheet(isPresented: $isPickingFromLibrary) {
            LibraryPickerSheet(
                title: "Ajouter au projet",
                emptyMessage: "Créez d'abord du matériel dans la bibliothèque.",
                items: availableEquipment,
                searchText: { $0.searchHaystack },
                onSelect: { item in
                    LibraryService.assign(item, to: project, context: modelContext)
                },
                row: { EquipmentRow(item: $0) }
            )
        }
        .sheet(item: $assignmentBeingEdited) { assignment in
            EquipmentAssignmentSheet(assignment: assignment)
        }
        .sheet(item: $itemBeingCreated) { item in
            EquipmentEditorSheet(item: item)
        }
    }

    private var list: some View {
        List {
            Section {
                HStack {
                    Text(AppFormat.count(assignments.count, singular: "référence", plural: "références", zero: "Aucune référence"))
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

            ForEach(groups, id: \.category) { group in
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
                                Label("Retirer", systemImage: "minus.circle")
                            }
                        }
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

    @ViewBuilder
    private func row(for assignment: ProjectEquipmentAssignment) -> some View {
        if let item = assignment.equipment {
            EquipmentRow(
                item: item,
                trailingText: assignment.estimatedCost.map { AppFormat.currency($0) }
                    ?? "×\(assignment.quantity)"
            )
        } else {
            Text("Matériel supprimé")
                .foregroundStyle(.secondary)
        }
    }

    private var emptyState: some View {
        EmptyStateView(
            symbolName: "shippingbox",
            title: "Aucun matériel",
            message: "Composez la liste de matériel du projet à partir de votre bibliothèque : quantités, jours et tarifs.",
            tint: .teal
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

                Button("Créer du matériel") { createAndAssign() }
                    .buttonStyle(.borderless)
            }
        }
    }

    private func createAndAssign() {
        let item = LibraryService.createEquipment(context: modelContext)
        LibraryService.assign(item, to: project, context: modelContext)
        itemBeingCreated = item
    }
}

/// Project-specific settings for one piece of gear: quantity, days, rate.
struct EquipmentAssignmentSheet: View {
    @Bindable var assignment: ProjectEquipmentAssignment

    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var modelContext
    @State private var isEditingItem = false

    var body: some View {
        NavigationStack {
            Form {
                Section("Matériel") {
                    LabeledContent("Nom", value: assignment.equipmentDisplayName)
                    Button("Modifier la fiche") { isEditingItem = true }
                        .disabled(assignment.equipment == nil)
                }

                Section("Sur ce projet") {
                    Stepper(value: $assignment.quantity, in: 1...99) {
                        LabeledContent("Quantité", value: "\(assignment.quantity)")
                    }
                    Stepper(value: $assignment.numberOfDays, in: 1...365) {
                        LabeledContent("Nombre de jours", value: "\(assignment.numberOfDays)")
                    }
                    LabeledContent("Tarif journalier") {
                        TextField(
                            assignment.equipment?.defaultDailyRate.map { AppFormat.currency($0) } ?? "—",
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
                    Text("Le matériel reste dans la bibliothèque.")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }
            .creativoFormStyle()
            .navigationTitle(assignment.equipmentDisplayName)
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
            .sheet(isPresented: $isEditingItem) {
                if let item = assignment.equipment {
                    EquipmentEditorSheet(item: item)
                }
            }
        }
        .macSheetFrame(minWidth: 520, minHeight: 560)
    }
}

#Preview {
    NavigationStack {
        ProjectEquipmentView(project: SampleData.previewProject())
    }
    .modelContainer(SampleData.previewContainer)
}
