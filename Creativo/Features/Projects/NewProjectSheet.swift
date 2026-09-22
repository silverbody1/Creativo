import SwiftUI
import SwiftData

/// Two-step project creation: pick a kind, then name it.
struct NewProjectSheet: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var modelContext
    @Environment(AppState.self) private var appState

    @State private var selectedType: ProjectType?
    @State private var name = ""
    @State private var targetBudget: Decimal?
    @State private var openAfterCreation = true
    @FocusState private var isNameFocused: Bool

    var body: some View {
        NavigationStack {
            Group {
                if let type = selectedType {
                    detailsStep(for: type)
                } else {
                    typeStep
                }
            }
            .navigationTitle("Créer un projet")
            .inlineNavigationTitle()
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Annuler") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Créer le projet") { create() }
                        .disabled(selectedType == nil)
                        .keyboardShortcut(.defaultAction)
                }
            }
        }
        .macSheetFrame(minWidth: 640, minHeight: 580)
    }

    // MARK: Step 1

    private var typeStep: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: Spacing.lg) {
                Text("Quel type de projet voulez-vous créer ?")
                    .font(.title3.weight(.semibold))
                Text("Le type oriente les sections et les modèles proposés. Il reste modifiable à tout moment.")
                    .font(.callout)
                    .foregroundStyle(.secondary)

                LazyVGrid(
                    columns: [GridItem(.adaptive(minimum: 208), spacing: Spacing.md)],
                    spacing: Spacing.md
                ) {
                    ForEach(ProjectType.allCases) { type in
                        ProjectTypeCard(type: type, isSelected: selectedType == type) {
                            withAnimation(.smooth(duration: 0.2)) {
                                selectedType = type
                            }
                            isNameFocused = true
                        }
                    }
                }
            }
            .padding(Spacing.xl)
        }
    }

    // MARK: Step 2

    private func detailsStep(for type: ProjectType) -> some View {
        ScrollView {
            VStack(alignment: .leading, spacing: Spacing.xl) {
                Button {
                    withAnimation(.smooth(duration: 0.2)) { selectedType = nil }
                } label: {
                    Label("Changer de type", systemImage: "chevron.left")
                        .font(.callout)
                }
                .buttonStyle(.borderless)

                HStack(spacing: Spacing.md) {
                    IconTile(symbolName: type.symbolName, tint: type.tint, size: 48)
                    VStack(alignment: .leading, spacing: Spacing.xxs) {
                        Text(type.displayName)
                            .font(.headline)
                        Text(type.shortDescription)
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                    Spacer(minLength: 0)
                }
                .cardSurface()

                VStack(alignment: .leading, spacing: Spacing.lg) {
                    VStack(alignment: .leading, spacing: Spacing.xs) {
                        Text("Nom du projet")
                            .font(.subheadline.weight(.medium))
                        TextField(ProjectService.defaultName(for: type), text: $name)
                            .textFieldStyle(.plain)
                            .font(.title3)
                            .focused($isNameFocused)
                            .padding(Spacing.md)
                            .background(Surface.card, in: RoundedRectangle(cornerRadius: CornerRadius.medium, style: .continuous))
                            .onSubmit(create)
                    }

                    VStack(alignment: .leading, spacing: Spacing.xs) {
                        Text("Budget cible")
                            .font(.subheadline.weight(.medium))
                        HStack {
                            TextField(
                                "Optionnel",
                                value: Binding<Decimal>.optionalAmount($targetBudget),
                                format: .currency(code: AppFormat.currencyCode)
                            )
                            .textFieldStyle(.plain)
                            .padding(Spacing.md)
                            .background(Surface.card, in: RoundedRectangle(cornerRadius: CornerRadius.medium, style: .continuous))
                        }
                        Text("Vous pourrez l'ajuster et détailler les lignes budgétaires plus tard.")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }

                    Toggle("Ouvrir le projet après création", isOn: $openAfterCreation)
                        .toggleStyle(.switch)
                }
            }
            .padding(Spacing.xl)
            .frame(maxWidth: LayoutMetrics.formMaxWidth, alignment: .leading)
            .frame(maxWidth: .infinity, alignment: .leading)
        }
    }

    // MARK: Actions

    private func create() {
        guard let type = selectedType else { return }
        let project = ProjectService.create(
            name: name,
            type: type,
            targetBudget: targetBudget,
            in: modelContext
        )
        dismiss()
        if openAfterCreation {
            appState.open(project)
        }
    }
}

#Preview {
    NewProjectSheet()
        .environment(AppState())
        .modelContainer(SampleData.previewContainer)
}
