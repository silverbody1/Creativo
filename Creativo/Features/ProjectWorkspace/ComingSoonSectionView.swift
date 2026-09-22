import SwiftUI

/// Real empty state for the sections that land in a later phase.
///
/// Never a placeholder label: each one states what the section will do and
/// offers the action that will create its first item, so the navigation is
/// already complete and only the feature itself is missing.
struct ComingSoonSectionView: View {
    let section: WorkspaceSection
    let project: Project

    @Environment(AppState.self) private var appState

    var body: some View {
        EmptyStateView(
            symbolName: section.symbolName,
            title: copy.title,
            message: copy.message,
            tint: copy.tint
        ) {
            VStack(spacing: Spacing.md) {
                Button {
                    appState.workspaceSection = copy.fallbackSection
                } label: {
                    Label(copy.actionTitle, systemImage: copy.actionSymbol)
                        .touchTarget()
                        .padding(.horizontal, Spacing.sm)
                }
                .buttonStyle(.borderedProminent)
                .controlSize(.large)

                Text("Disponible dans une prochaine phase.")
                    .font(.caption)
                    .foregroundStyle(.tertiary)
            }
        }
        .navigationTitle(section.displayName)
        .inlineNavigationTitle()
    }

    private struct Copy {
        let title: String
        let message: String
        let tint: Color
        let actionTitle: String
        let actionSymbol: String
        let fallbackSection: WorkspaceSection
    }

    private var copy: Copy {
        switch section {
        case .board:
            return Copy(
                title: "Board",
                message: "Construisez l'univers visuel de votre projet : références, palettes, cadres et intentions sur un canevas libre.",
                tint: .purple,
                actionTitle: "Voir les plans en attendant",
                actionSymbol: "camera.viewfinder",
                fallbackSection: .shots
            )
        case .documents:
            return Copy(
                title: "Documents",
                message: "Feuilles de service, dépouillements et exports PDF seront générés à partir de vos scènes, de votre équipe et de votre planning.",
                tint: .orange,
                actionTitle: "Préparer le planning",
                actionSymbol: "calendar",
                fallbackSection: .schedule
            )
        default:
            return Copy(
                title: section.displayName,
                message: "Cette section arrive bientôt.",
                tint: .accentColor,
                actionTitle: "Vue d'ensemble",
                actionSymbol: "square.grid.2x2",
                fallbackSection: .overview
            )
        }
    }
}

#Preview {
    NavigationStack {
        ComingSoonSectionView(section: .board, project: Project(name: "PARTENAIRE", type: .musicVideo))
    }
    .environment(AppState())
}
