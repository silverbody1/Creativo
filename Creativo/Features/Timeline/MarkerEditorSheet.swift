import SwiftUI
import SwiftData

/// Creates or edits a marker.
struct MarkerEditorSheet: View {
    @Bindable var marker: TimelineMarker
    let project: Project

    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var modelContext
    @State private var isConfirmingDeletion = false

    var body: some View {
        NavigationStack {
            Form {
                Section("Repère") {
                    TextField("Titre", text: $marker.title, prompt: Text("drop, entrée batterie, « partenaire »…"))
                    Picker("Type", selection: $marker.type) {
                        ForEach(TimelineMarkerType.allCases) { type in
                            Label(type.displayName, systemImage: type.symbolName).tag(type)
                        }
                    }
                }

                Section("Position") {
                    LabeledContent("Temps") {
                        DurationField(duration: $marker.time)
                    }
                    LabeledContent("Timecode", value: AppFormat.preciseTimecode(marker.time))
                }

                Section("Notes") {
                    TextField("Ce qu'il faut retenir à cet instant", text: $marker.notes, axis: .vertical)
                        .lineLimit(2...6)
                }

                Section {
                    Button("Supprimer le repère", role: .destructive) {
                        isConfirmingDeletion = true
                    }
                }
            }
            .creativoFormStyle()
            .navigationTitle(marker.displayTitle)
            .inlineNavigationTitle()
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Terminé") {
                        MusicTimelineService.commitEdits(to: marker, in: project, context: modelContext)
                        dismiss()
                    }
                    .keyboardShortcut(.defaultAction)
                }
            }
            .confirmationDialog("Supprimer ce repère ?", isPresented: $isConfirmingDeletion) {
                Button("Supprimer", role: .destructive) {
                    MusicTimelineService.delete(marker, context: modelContext)
                    dismiss()
                }
                Button("Annuler", role: .cancel) {}
            } message: {
                Text("« \(marker.displayTitle) » sera retiré de la timeline.")
            }
        }
        .macSheetFrame(minWidth: 460, minHeight: 440, idealWidth: 500, idealHeight: 460)
    }
}
