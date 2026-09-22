import SwiftUI
import SwiftData

/// The project budget: headline figures, then lines grouped by category.
///
/// Every total is derived on read, so editing a line updates the header, the
/// category subtotal and the project dashboard in the same frame.
struct BudgetView: View {
    @Bindable var project: Project

    @Environment(\.modelContext) private var modelContext
    @State private var lineBeingEdited: BudgetLine?
    @State private var linePendingDeletion: BudgetLine?
    @State private var isEditingTarget = false

    private var summary: BudgetSummary { project.budgetSummary }
    private var categories: [BudgetCategoryTotal] { project.budgetTotalsByCategory }

    var body: some View {
        Group {
            if project.budgetLines.isEmpty {
                emptyState
            } else {
                list
            }
        }
        .navigationTitle("Budget")
        .inlineNavigationTitle()
        .toolbar {
            ToolbarItem(placement: .primaryAction) {
                Menu {
                    ForEach(BudgetCategory.allCases) { category in
                        Button {
                            addLine(category: category)
                        } label: {
                            Label(category.displayName, systemImage: category.symbolName)
                        }
                    }
                } label: {
                    Label("Nouvelle ligne", systemImage: "plus")
                }
            }
            ToolbarItem(placement: .automatic) {
                Button {
                    isEditingTarget = true
                } label: {
                    Label("Budget cible", systemImage: "target")
                }
            }
        }
        .sheet(item: $lineBeingEdited) { line in
            BudgetLineEditorSheet(line: line)
        }
        .sheet(isPresented: $isEditingTarget) {
            TargetBudgetSheet(project: project)
        }
        .confirmationDialog(
            "Supprimer cette ligne ?",
            isPresented: deletionBinding,
            presenting: linePendingDeletion
        ) { line in
            Button("Supprimer", role: .destructive) {
                BudgetService.delete(line, in: modelContext)
                linePendingDeletion = nil
            }
            Button("Annuler", role: .cancel) { linePendingDeletion = nil }
        } message: { line in
            Text("« \(line.displayTitle) » sera retirée du budget.")
        }
    }

    // MARK: List

    private var list: some View {
        List {
            Section {
                summaryHeader
                    .listRowInsets(EdgeInsets())
                    .listRowBackground(Color.clear)
            }

            ForEach(categories) { group in
                Section {
                    ForEach(group.lines) { line in
                        Button {
                            lineBeingEdited = line
                        } label: {
                            BudgetLineRow(line: line)
                        }
                        .buttonStyle(.plain)
                        .contextMenu {
                            Button("Modifier") { lineBeingEdited = line }
                            Divider()
                            Button("Supprimer…", role: .destructive) { linePendingDeletion = line }
                        }
                        .swipeActions(edge: .trailing) {
                            Button(role: .destructive) {
                                linePendingDeletion = line
                            } label: {
                                Label("Supprimer", systemImage: "trash")
                            }
                        }
                    }
                } header: {
                    HStack(spacing: Spacing.sm) {
                        Image(systemName: group.category.symbolName)
                            .foregroundStyle(group.category.tint)
                        Text(group.category.displayName)
                            .font(.caption.weight(.semibold))
                        Spacer(minLength: Spacing.sm)
                        Text(AppFormat.currency(group.forecast))
                            .font(.caption.monospacedDigit().weight(.semibold))
                    }
                    .textCase(nil)
                } footer: {
                    if group.spent > 0 {
                        Text("Déjà payé : \(AppFormat.currency(group.spent))")
                            .font(.caption)
                    }
                }
            }

            Section {
                HStack {
                    Text("Total général")
                        .font(.headline)
                    Spacer()
                    Text(AppFormat.currencyDetailed(summary.forecast))
                        .font(.headline.monospacedDigit())
                }
                .touchTarget()
            }
        }
    }

    private var summaryHeader: some View {
        VStack(spacing: Spacing.md) {
            LazyVGrid(
                columns: [GridItem(.adaptive(minimum: 150), spacing: Spacing.md)],
                spacing: Spacing.md
            ) {
                figure("Budget cible", AppFormat.optionalCurrency(summary.target, placeholder: "Non défini"), tint: .secondary)
                figure("Prévisionnel", AppFormat.currency(summary.forecast), tint: summary.isOverTarget ? .red : .blue)
                figure("Dépensé", AppFormat.currency(summary.spent), tint: .orange)
                figure(
                    "Restant",
                    summary.remaining.map { AppFormat.currency($0) } ?? "—",
                    tint: (summary.remaining ?? 0) < 0 ? .red : .green
                )
            }

            if let ratio = summary.forecastRatio {
                VStack(alignment: .leading, spacing: Spacing.xs) {
                    ProgressView(value: min(ratio, 1))
                        .tint(summary.isOverTarget ? .red : .green)
                    HStack {
                        Text("Prévisionnel / cible")
                        Spacer()
                        Text(AppFormat.percentage(ratio))
                            .monospacedDigit()
                        if let margin = summary.targetMargin {
                            Text("·")
                                .foregroundStyle(.tertiary)
                            Text(AppFormat.signedCurrency(margin))
                                .monospacedDigit()
                                .foregroundStyle(margin < 0 ? Color.red : Color.green)
                        }
                    }
                    .font(.caption)
                    .foregroundStyle(.secondary)
                }
            }
        }
        .cardSurface()
        .padding(.vertical, Spacing.sm)
    }

    private func figure(_ label: String, _ value: String, tint: Color) -> some View {
        VStack(alignment: .leading, spacing: Spacing.xxs) {
            Text(label.uppercased())
                .font(.caption2.weight(.semibold))
                .tracking(0.6)
                .foregroundStyle(.secondary)
            Text(value)
                .font(.system(.title3, design: .rounded, weight: .semibold))
                .monospacedDigit()
                .foregroundStyle(tint)
                .lineLimit(1)
                .minimumScaleFactor(0.6)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private var emptyState: some View {
        EmptyStateView(
            symbolName: "eurosign.circle",
            title: "Budget vide",
            message: "Ajoutez vos lignes budgétaires : le total se calcule automatiquement et se compare à votre budget cible.",
            tint: .green
        ) {
            VStack(spacing: Spacing.sm) {
                Button {
                    addLine(category: .equipment)
                } label: {
                    Label("Créer la première ligne", systemImage: "plus")
                        .touchTarget()
                        .padding(.horizontal, Spacing.sm)
                }
                .buttonStyle(.borderedProminent)
                .controlSize(.large)

                Button("Définir le budget cible") { isEditingTarget = true }
                    .buttonStyle(.borderless)
            }
        }
    }

    // MARK: Actions

    private var deletionBinding: Binding<Bool> {
        Binding(
            get: { linePendingDeletion != nil },
            set: { if !$0 { linePendingDeletion = nil } }
        )
    }

    private func addLine(category: BudgetCategory) {
        lineBeingEdited = BudgetService.create(in: project, category: category, in: modelContext)
    }
}

/// One budget line row: title, formula, total.
struct BudgetLineRow: View {
    let line: BudgetLine

    var body: some View {
        HStack(spacing: Spacing.md) {
            VStack(alignment: .leading, spacing: Spacing.xxs) {
                Text(line.displayTitle)
                    .font(.body.weight(.medium))
                    .lineLimit(1)
                HStack(spacing: Spacing.xs) {
                    Text("\(line.quantity) × \(AppFormat.currency(line.unitPrice)) × \(line.numberOfDays) j")
                        .font(.caption.monospacedDigit())
                        .foregroundStyle(.secondary)
                    if line.taxRate != nil {
                        Chip(text: "TVA", style: .neutral)
                    }
                }
            }

            Spacer(minLength: Spacing.sm)

            VStack(alignment: .trailing, spacing: Spacing.xxs) {
                Text(AppFormat.currency(line.estimatedTotal))
                    .font(.body.monospacedDigit().weight(.medium))
                    .foregroundStyle(line.status == .cancelled ? Color.secondary : Color.primary)
                    .strikethrough(line.status == .cancelled)
                StatusDot(text: line.status.displayName, tint: line.status.tint)
            }
        }
        .touchTarget()
    }
}

/// Small sheet dedicated to the target envelope.
struct TargetBudgetSheet: View {
    @Bindable var project: Project

    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var modelContext

    var body: some View {
        NavigationStack {
            Form {
                Section("Budget cible") {
                    TextField(
                        "Montant",
                        value: Binding<Decimal>.optionalAmount($project.targetBudget),
                        format: .currency(code: AppFormat.currencyCode)
                    )
                    .decimalKeyboard()
                    Text("Laissez à zéro pour ne pas fixer d'enveloppe.")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }
            .creativoFormStyle()
            .navigationTitle("Budget cible")
            .inlineNavigationTitle()
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Terminé") {
                        BudgetService.setTarget(project.targetBudget, on: project, in: modelContext)
                        dismiss()
                    }
                    .keyboardShortcut(.defaultAction)
                }
            }
        }
        .macSheetFrame(minWidth: 420, minHeight: 260, idealWidth: 460, idealHeight: 280)
    }
}

#Preview {
    NavigationStack {
        BudgetView(project: SampleData.previewProject())
    }
    .modelContainer(SampleData.previewContainer)
}
