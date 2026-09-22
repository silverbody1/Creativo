import SwiftUI
import SwiftData

/// App preferences and a look at what the library holds.
struct SettingsView: View {
    @Environment(\.modelContext) private var modelContext
    @AppStorage("appAppearance") private var appearance: AppAppearance = .system

    @Query private var projects: [Project]
    @Query private var people: [Person]
    @Query private var locations: [ProductionLocation]
    @Query private var equipment: [EquipmentItem]

    @State private var isConfirmingSampleData = false

    var body: some View {
        Form {
            Section("Apparence") {
                Picker("Thème", selection: $appearance) {
                    ForEach(AppAppearance.allCases) { value in
                        Label(value.displayName, systemImage: value.symbolName)
                            .tag(value)
                    }
                }
                .pickerStyle(.inline)
            }

            Section("Bibliothèque") {
                LabeledContent("Projets", value: "\(projects.count)")
                LabeledContent("Personnes", value: "\(people.count)")
                LabeledContent("Lieux", value: "\(locations.count)")
                LabeledContent("Matériel", value: "\(equipment.count)")
            }

            Section("Données") {
                LabeledContent("Stockage", value: "Local (SwiftData)")
                LabeledContent("Devise", value: AppFormat.currencyCode)
                Text("La synchronisation iCloud est prévue pour une phase ultérieure. L'application fonctionne entièrement hors ligne et ne dépend d'aucun compte.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            #if DEBUG
            Section("Développement") {
                Button("Charger les données de démonstration") {
                    isConfirmingSampleData = true
                }
                Text("Ajoute un projet d'exemple et quelques éléments de bibliothèque. Visible uniquement dans les versions de développement.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            #endif

            Section("À propos") {
                LabeledContent("Version", value: Self.versionString)
                LabeledContent("Phase", value: "1 — Fondations")
            }
        }
        .creativoFormStyle()
        .navigationTitle("Réglages")
        .inlineNavigationTitle()
        .confirmationDialog(
            "Charger les données de démonstration ?",
            isPresented: $isConfirmingSampleData
        ) {
            Button("Charger") {
                SampleData.populate(modelContext)
            }
            Button("Annuler", role: .cancel) {}
        } message: {
            Text("Un projet d'exemple et des éléments de bibliothèque seront ajoutés à vos données.")
        }
    }

    private static var versionString: String {
        let info = Bundle.main.infoDictionary
        let short = (info?["CFBundleShortVersionString"] as? String) ?? "0.1.0"
        let build = (info?["CFBundleVersion"] as? String) ?? "1"
        return "\(short) (\(build))"
    }
}

#Preview {
    NavigationStack {
        SettingsView()
    }
    .modelContainer(SampleData.previewContainer)
}
