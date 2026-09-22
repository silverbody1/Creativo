import SwiftUI
import SwiftData

/// Creates or edits a shooting day.
struct ShootDayEditorSheet: View {
    @Bindable var day: ShootDay

    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var modelContext
    @State private var isConfirmingDeletion = false

    var body: some View {
        NavigationStack {
            Form {
                Section("Journée") {
                    TextField("Titre", text: $day.title, prompt: Text("Jour 1"))
                    DatePicker("Date", selection: $day.date, displayedComponents: .date)
                }

                Section("Horaires") {
                    DatePicker(
                        "Convocation",
                        selection: Binding<Date>.optionalDate($day.callTime, fallback: day.date),
                        displayedComponents: .hourAndMinute
                    )
                    DatePicker(
                        "Fin estimée",
                        selection: Binding<Date>.optionalDate($day.estimatedWrapTime, fallback: day.date),
                        displayedComponents: .hourAndMinute
                    )
                    if let duration = day.plannedDuration {
                        LabeledContent("Amplitude", value: AppFormat.duration(duration))
                    }
                }

                Section("Notes") {
                    TextField("Logistique, contraintes, rappels", text: $day.notes, axis: .vertical)
                        .lineLimit(3...8)
                }

                Section {
                    Button("Supprimer la journée", role: .destructive) {
                        isConfirmingDeletion = true
                    }
                }
            }
            .creativoFormStyle()
            .navigationTitle(day.displayTitle)
            .inlineNavigationTitle()
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Terminé") {
                        ScheduleService.commitEdits(to: day, context: modelContext)
                        dismiss()
                    }
                    .keyboardShortcut(.defaultAction)
                }
            }
            .confirmationDialog("Supprimer cette journée ?", isPresented: $isConfirmingDeletion) {
                Button("Supprimer", role: .destructive) {
                    ScheduleService.delete(day, context: modelContext)
                    dismiss()
                }
                Button("Annuler", role: .cancel) {}
            } message: {
                Text("« \(day.displayTitle) » sera retirée du planning.")
            }
        }
        .macSheetFrame(minWidth: 520, minHeight: 560)
    }
}

#Preview {
    ShootDayEditorSheet(day: ShootDay(date: .now, title: "Jour 1"))
        .modelContainer(SampleData.previewContainer)
}
