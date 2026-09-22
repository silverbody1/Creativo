import SwiftUI
import SwiftData

/// Edits the identity of a project: name, kind, status, synopsis, notes, budget.
struct ProjectSettingsSheet: View {
    @Bindable var project: Project

    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var modelContext

    var body: some View {
        NavigationStack {
            Form {
                Section("Identité") {
                    TextField("Nom du projet", text: $project.name)
                    Picker("Type", selection: $project.type) {
                        ForEach(ProjectType.allCases) { type in
                            Label(type.displayName, systemImage: type.symbolName)
                                .tag(type)
                        }
                    }
                    Picker("Statut", selection: $project.status) {
                        ForEach(ProjectStatus.allCases) { status in
                            Label(status.displayName, systemImage: status.symbolName)
                                .tag(status)
                        }
                    }
                    Toggle("Favori", isOn: $project.isFavorite)
                }

                Section("Budget") {
                    TextField(
                        "Budget cible",
                        value: Binding<Decimal>.optionalAmount($project.targetBudget),
                        format: .currency(code: AppFormat.currencyCode)
                    )
                    if project.targetBudget == nil {
                        Text("Laissez à zéro pour ne pas fixer d'enveloppe.")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                }

                Section("Synopsis") {
                    TextField("Résumez votre intention", text: $project.synopsis, axis: .vertical)
                        .lineLimit(3...10)
                }

                Section("Notes") {
                    TextField("Notes de production", text: $project.notes, axis: .vertical)
                        .lineLimit(3...10)
                }
            }
            .creativoFormStyle()
            .navigationTitle("Réglages du projet")
            .inlineNavigationTitle()
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Terminé") {
                        ProjectService.commitEdits(to: project, context: modelContext)
                        dismiss()
                    }
                    .keyboardShortcut(.defaultAction)
                }
            }
        }
        .macSheetFrame(minWidth: 560, minHeight: 560)
    }
}

#Preview {
    ProjectSettingsSheet(project: SampleData.previewProject())
        .modelContainer(SampleData.previewContainer)
}
