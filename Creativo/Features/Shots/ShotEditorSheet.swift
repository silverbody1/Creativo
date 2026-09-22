import SwiftUI
import SwiftData

/// Creates or edits a shot.
struct ShotEditorSheet: View {
    @Bindable var shot: Shot

    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var modelContext
    @State private var isConfirmingDeletion = false

    var body: some View {
        NavigationStack {
            Form {
                Section("Identification") {
                    TextField("Numéro", text: $shot.shotNumber)
                        .rawTextField()
                    TextField("Titre", text: $shot.title)
                }

                Section("Cadrage") {
                    Picker("Valeur de plan", selection: $shot.shotSize) {
                        ForEach(ShotSize.allCases) { size in
                            Text(size.displayName).tag(size)
                        }
                    }
                    Picker("Mouvement", selection: $shot.cameraMovement) {
                        ForEach(CameraMovement.allCases) { movement in
                            Text(movement.displayName).tag(movement)
                        }
                    }
                    TextField("Optique", text: $shot.lens, prompt: Text("35 mm"))
                    Picker("Cadence", selection: $shot.frameRate) {
                        ForEach(Shot.commonFrameRates, id: \.self) { rate in
                            Text(AppFormat.frameRate(rate)).tag(rate)
                        }
                    }
                }

                Section("Description") {
                    TextField("Ce que l'on voit", text: $shot.details, axis: .vertical)
                        .lineLimit(2...6)
                }

                Section("Suivi") {
                    Picker("Statut", selection: $shot.status) {
                        ForEach(ShotStatus.allCases) { status in
                            Label(status.displayName, systemImage: status.symbolName)
                                .tag(status)
                        }
                    }
                    TextField("Notes", text: $shot.notes, axis: .vertical)
                        .lineLimit(2...6)
                }

                Section {
                    Button("Supprimer le plan", role: .destructive) {
                        isConfirmingDeletion = true
                    }
                }
            }
            .creativoFormStyle()
            .navigationTitle("Plan \(shot.displayNumber)")
            .inlineNavigationTitle()
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Terminé") {
                        ShotService.commitEdits(to: shot, context: modelContext)
                        dismiss()
                    }
                    .keyboardShortcut(.defaultAction)
                }
            }
            .confirmationDialog(
                "Supprimer ce plan ?",
                isPresented: $isConfirmingDeletion
            ) {
                Button("Supprimer", role: .destructive) {
                    ShotService.delete(shot, context: modelContext)
                    dismiss()
                }
                Button("Annuler", role: .cancel) {}
            } message: {
                Text("Le plan « \(shot.displayTitle) » sera définitivement supprimé.")
            }
        }
        .macSheetFrame(minWidth: 540, minHeight: 620)
    }
}

#Preview {
    ShotEditorSheet(shot: Shot(shotNumber: "1A", title: "Plongée sur la ville", shotSize: .extremeWide, cameraMovement: .drone))
        .modelContainer(SampleData.previewContainer)
}
