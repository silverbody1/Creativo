import SwiftUI
import SwiftData

/// Creates or edits someone in the global library.
struct PersonEditorSheet: View {
    @Bindable var person: Person

    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var modelContext
    @State private var isConfirmingDeletion = false

    var body: some View {
        NavigationStack {
            Form {
                Section("Identité") {
                    TextField("Prénom", text: $person.firstName)
                    TextField("Nom", text: $person.lastName)
                    TextField("Nom d'usage", text: $person.nickname, prompt: Text("Nom de scène, surnom…"))
                    Picker("Rôle par défaut", selection: $person.role) {
                        ForEach(CrewRole.allCases) { role in
                            Text(role.displayName).tag(role)
                        }
                    }
                }

                Section("Contact") {
                    TextField("E-mail", text: $person.email)
                        .rawTextField()
                    TextField("Téléphone", text: $person.phone)
                        .rawTextField()
                }

                Section("Tarif") {
                    LabeledContent("Tarif journalier") {
                        TextField(
                            "—",
                            value: Binding<Decimal>.optionalAmount($person.defaultRate),
                            format: .currency(code: AppFormat.currencyCode)
                        )
                        .multilineTextAlignment(.trailing)
                        .decimalKeyboard()
                    }
                }

                Section("Notes") {
                    TextField("Disponibilités, spécialités, remarques", text: $person.notes, axis: .vertical)
                        .lineLimit(3...8)
                }

                if person.projectCount > 0 {
                    Section("Projets") {
                        LabeledContent(
                            "Participations",
                            value: AppFormat.count(person.projectCount, singular: "projet", plural: "projets", zero: "Aucun")
                        )
                    }
                }

                Section {
                    Button("Supprimer de la bibliothèque", role: .destructive) {
                        isConfirmingDeletion = true
                    }
                }
            }
            .creativoFormStyle()
            .navigationTitle(person.displayName)
            .inlineNavigationTitle()
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Terminé") {
                        person.touch()
                        LibraryService.commitEdits(in: modelContext)
                        dismiss()
                    }
                    .keyboardShortcut(.defaultAction)
                }
            }
            .confirmationDialog("Supprimer cette personne ?", isPresented: $isConfirmingDeletion) {
                Button("Supprimer", role: .destructive) {
                    LibraryService.deletePerson(person, in: modelContext)
                    dismiss()
                }
                Button("Annuler", role: .cancel) {}
            } message: {
                Text("« \(person.displayName) » sera retirée de la bibliothèque et de ses \(person.projectCount) projet(s).")
            }
        }
        .macSheetFrame(minWidth: 540, minHeight: 640)
    }
}

#Preview {
    PersonEditorSheet(person: Person(firstName: "Camille", lastName: "Roux", role: .directorOfPhotography))
        .modelContainer(SampleData.previewContainer)
}
