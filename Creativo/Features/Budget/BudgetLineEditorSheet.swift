import SwiftUI
import SwiftData

/// Creates or edits one budget line, with a live total.
struct BudgetLineEditorSheet: View {
    @Bindable var line: BudgetLine

    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var modelContext
    @State private var isConfirmingDeletion = false
    @State private var appliesTax: Bool

    init(line: BudgetLine) {
        self.line = line
        _appliesTax = State(initialValue: line.taxRate != nil)
    }

    var body: some View {
        NavigationStack {
            Form {
                Section("Ligne") {
                    TextField("Intitulé", text: $line.title, prompt: Text("Location caméra, cachet danseur…"))
                    Picker("Catégorie", selection: $line.category) {
                        ForEach(BudgetCategory.allCases) { category in
                            Label(category.displayName, systemImage: category.symbolName)
                                .tag(category)
                        }
                    }
                }

                Section("Calcul") {
                    Stepper(value: $line.quantity, in: 1...999) {
                        LabeledContent("Quantité", value: "\(line.quantity)")
                    }
                    LabeledContent("Prix unitaire") {
                        TextField(
                            "0",
                            value: $line.unitPrice,
                            format: .currency(code: AppFormat.currencyCode)
                        )
                        .multilineTextAlignment(.trailing)
                        .decimalKeyboard()
                    }
                    Stepper(value: $line.numberOfDays, in: 1...365) {
                        LabeledContent("Nombre de jours", value: "\(line.numberOfDays)")
                    }

                    Toggle("Appliquer la TVA", isOn: $appliesTax)
                        .onChange(of: appliesTax) { _, isOn in
                            line.taxRate = isOn ? (line.taxRate ?? BudgetLine.defaultTaxRate) : nil
                        }
                    if appliesTax {
                        LabeledContent("Taux") {
                            TextField(
                                "0,20",
                                value: Binding(get: { line.taxRate ?? 0 }, set: { line.taxRate = $0 }),
                                format: .percent
                            )
                            .multilineTextAlignment(.trailing)
                            .decimalKeyboard()
                        }
                    }
                }

                Section("Total") {
                    LabeledContent("Sous-total", value: AppFormat.currencyDetailed(line.subtotal))
                    if appliesTax {
                        LabeledContent("TVA", value: AppFormat.currencyDetailed(line.taxAmount))
                    }
                    LabeledContent("Total prévisionnel") {
                        Text(AppFormat.currencyDetailed(line.estimatedTotal))
                            .font(.headline.monospacedDigit())
                    }
                }

                Section("Suivi") {
                    Picker("Statut", selection: $line.status) {
                        ForEach(BudgetLineStatus.allCases) { status in
                            Label(status.displayName, systemImage: status.symbolName)
                                .tag(status)
                        }
                    }
                    LabeledContent("Montant réellement payé") {
                        TextField(
                            "—",
                            value: Binding<Decimal>.optionalAmount($line.actualAmount),
                            format: .currency(code: AppFormat.currencyCode)
                        )
                        .multilineTextAlignment(.trailing)
                        .decimalKeyboard()
                    }
                    if let variance = line.variance {
                        LabeledContent("Écart") {
                            Text(AppFormat.signedCurrency(variance))
                                .foregroundStyle(variance > 0 ? Color.red : Color.green)
                                .monospacedDigit()
                        }
                    }
                    TextField("Notes", text: $line.notes, axis: .vertical)
                        .lineLimit(2...5)
                }

                Section {
                    Button("Supprimer la ligne", role: .destructive) {
                        isConfirmingDeletion = true
                    }
                }
            }
            .creativoFormStyle()
            .navigationTitle("Ligne budgétaire")
            .inlineNavigationTitle()
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Terminé") {
                        BudgetService.commitEdits(to: line, in: modelContext)
                        dismiss()
                    }
                    .keyboardShortcut(.defaultAction)
                }
            }
            .confirmationDialog("Supprimer cette ligne ?", isPresented: $isConfirmingDeletion) {
                Button("Supprimer", role: .destructive) {
                    BudgetService.delete(line, in: modelContext)
                    dismiss()
                }
                Button("Annuler", role: .cancel) {}
            } message: {
                Text("« \(line.displayTitle) » sera retirée du budget.")
            }
        }
        .macSheetFrame(minWidth: 560, minHeight: 680)
    }
}

#Preview {
    BudgetLineEditorSheet(
        line: BudgetLine(category: .equipment, title: "Location FX3", quantity: 1, unitPrice: 180, numberOfDays: 2)
    )
    .modelContainer(SampleData.previewContainer)
}
