import SwiftUI
import SwiftData

/// Creates or edits a piece of gear in the global library.
struct EquipmentEditorSheet: View {
    @Bindable var item: EquipmentItem

    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var modelContext
    @State private var isConfirmingDeletion = false

    var body: some View {
        NavigationStack {
            Form {
                Section("Matériel") {
                    TextField("Nom", text: $item.name, prompt: Text("FX3, 35 mm, Aputure 600…"))
                    Picker("Catégorie", selection: $item.category) {
                        ForEach(EquipmentCategory.allCases) { category in
                            Label(category.displayName, systemImage: category.symbolName)
                                .tag(category)
                        }
                    }
                    TextField("Marque", text: $item.brand)
                    TextField("Modèle", text: $item.model)
                }

                Section("Disponibilité") {
                    Toggle("Matériel possédé", isOn: $item.owned)
                    Stepper(value: $item.quantity, in: 1...99) {
                        LabeledContent("Quantité", value: "\(item.quantity)")
                    }
                    LabeledContent("Tarif journalier") {
                        TextField(
                            "—",
                            value: Binding<Decimal>.optionalAmount($item.defaultDailyRate),
                            format: .currency(code: AppFormat.currencyCode)
                        )
                        .multilineTextAlignment(.trailing)
                        .decimalKeyboard()
                    }
                    if item.owned {
                        Text("Le matériel possédé peut garder un tarif : il sert à valoriser votre apport dans le budget.")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                }

                Section("Notes") {
                    TextField("Références, accessoires, état", text: $item.notes, axis: .vertical)
                        .lineLimit(3...8)
                }

                Section {
                    Button("Supprimer de la bibliothèque", role: .destructive) {
                        isConfirmingDeletion = true
                    }
                }
            }
            .creativoFormStyle()
            .navigationTitle(item.displayName)
            .inlineNavigationTitle()
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Terminé") {
                        item.touch()
                        LibraryService.commitEdits(in: modelContext)
                        dismiss()
                    }
                    .keyboardShortcut(.defaultAction)
                }
            }
            .confirmationDialog("Supprimer ce matériel ?", isPresented: $isConfirmingDeletion) {
                Button("Supprimer", role: .destructive) {
                    LibraryService.deleteEquipment(item, in: modelContext)
                    dismiss()
                }
                Button("Annuler", role: .cancel) {}
            } message: {
                Text("« \(item.displayName) » sera retiré de la bibliothèque et des projets qui l'utilisent.")
            }
        }
        .macSheetFrame(minWidth: 540, minHeight: 620)
    }
}

#Preview {
    EquipmentEditorSheet(item: EquipmentItem(name: "FX3", category: .camera, brand: "Sony", owned: true))
        .modelContainer(SampleData.previewContainer)
}
