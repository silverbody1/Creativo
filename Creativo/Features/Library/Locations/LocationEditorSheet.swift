import SwiftUI
import SwiftData

/// Creates or edits a location in the global library.
struct LocationEditorSheet: View {
    @Bindable var location: ProductionLocation

    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var modelContext
    @State private var isConfirmingDeletion = false

    var body: some View {
        NavigationStack {
            Form {
                Section("Lieu") {
                    TextField("Nom", text: $location.name, prompt: Text("Studio, rooftop, forêt…"))
                    TextField("Adresse", text: $location.address, axis: .vertical)
                        .lineLimit(1...3)
                }

                Section("Coordonnées GPS") {
                    LabeledContent("Latitude") {
                        TextField("—", text: Binding<String>.optionalDouble($location.latitude))
                            .multilineTextAlignment(.trailing)
                            .decimalKeyboard()
                            .rawTextField()
                    }
                    LabeledContent("Longitude") {
                        TextField("—", text: Binding<String>.optionalDouble($location.longitude))
                            .multilineTextAlignment(.trailing)
                            .decimalKeyboard()
                            .rawTextField()
                    }
                    Text("La carte et le repérage arriveront avec la phase Location Scouting.")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }

                Section("Contact") {
                    TextField("Nom du contact", text: $location.contactName)
                    TextField("E-mail", text: $location.contactEmail)
                        .rawTextField()
                    TextField("Téléphone", text: $location.contactPhone)
                        .rawTextField()
                }

                Section("Conditions") {
                    LabeledContent("Prix par jour") {
                        TextField(
                            "—",
                            value: Binding<Decimal>.optionalAmount($location.pricePerDay),
                            format: .currency(code: AppFormat.currencyCode)
                        )
                        .multilineTextAlignment(.trailing)
                        .decimalKeyboard()
                    }
                    Toggle("Électricité disponible", isOn: $location.powerAvailable)
                    Toggle("Sanitaires", isOn: $location.toiletsAvailable)
                    Toggle("Intérieur exploitable", isOn: $location.indoorAvailable)
                    Toggle("Extérieur exploitable", isOn: $location.outdoorAvailable)
                    Toggle("Tournage de nuit autorisé", isOn: $location.nightShootingAllowed)
                }

                Section("Stationnement") {
                    TextField("Où se garer, autorisations…", text: $location.parkingNotes, axis: .vertical)
                        .lineLimit(2...6)
                }

                Section("Notes") {
                    TextField("Remarques de repérage", text: $location.notes, axis: .vertical)
                        .lineLimit(3...8)
                }

                Section {
                    Button("Supprimer de la bibliothèque", role: .destructive) {
                        isConfirmingDeletion = true
                    }
                }
            }
            .creativoFormStyle()
            .navigationTitle(location.displayName)
            .inlineNavigationTitle()
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Terminé") {
                        location.touch()
                        LibraryService.commitEdits(in: modelContext)
                        dismiss()
                    }
                    .keyboardShortcut(.defaultAction)
                }
            }
            .confirmationDialog("Supprimer ce lieu ?", isPresented: $isConfirmingDeletion) {
                Button("Supprimer", role: .destructive) {
                    LibraryService.deleteLocation(location, in: modelContext)
                    dismiss()
                }
                Button("Annuler", role: .cancel) {}
            } message: {
                Text("« \(location.displayName) » sera retiré de la bibliothèque et des projets qui l'utilisent. Les scènes concernées perdront leur lieu.")
            }
        }
        .macSheetFrame(minWidth: 560, minHeight: 680)
    }
}

#Preview {
    LocationEditorSheet(location: ProductionLocation(name: "Studio Est", address: "12 rue des Lilas, Paris"))
        .modelContainer(SampleData.previewContainer)
}
