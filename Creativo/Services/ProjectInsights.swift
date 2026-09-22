import Foundation

/// One actionable gap detected on a project.
struct ProjectInsight: Identifiable, Hashable {
    let id: String
    let title: String
    let message: String
    let symbolName: String
    /// Section the user is sent to when they act on the insight.
    let section: WorkspaceSection
}

/// The "À préparer" list of the project dashboard.
///
/// Every rule is deterministic and derived only from stored data: no
/// heuristics, no guessing, nothing that could contradict what the user sees
/// elsewhere on the screen. New rules are appended here as features land.
enum ProjectInsights {
    static func insights(for project: Project) -> [ProjectInsight] {
        var result: [ProjectInsight] = []

        if project.scenes.isEmpty {
            result.append(
                ProjectInsight(
                    id: "no-scenes",
                    title: "Aucune scène",
                    message: "Découpez votre projet en scènes pour commencer le travail de préparation.",
                    symbolName: "list.bullet.rectangle",
                    section: .scenes
                )
            )
        } else if project.allShots.isEmpty {
            result.append(
                ProjectInsight(
                    id: "no-shots",
                    title: "Aucun plan",
                    message: "Ajoutez des plans à vos scènes pour construire la shot list.",
                    symbolName: "camera.viewfinder",
                    section: .shots
                )
            )
        }

        if project.shootDays.isEmpty {
            result.append(
                ProjectInsight(
                    id: "no-shoot-day",
                    title: "Aucune date de tournage",
                    message: "Placez au moins une journée de tournage pour caler le planning.",
                    symbolName: "calendar.badge.plus",
                    section: .schedule
                )
            )
        }

        if project.targetBudget == nil {
            result.append(
                ProjectInsight(
                    id: "no-target-budget",
                    title: "Aucun budget cible",
                    message: "Fixez une enveloppe pour suivre vos dépenses dès le départ.",
                    symbolName: "eurosign.circle",
                    section: .budget
                )
            )
        } else if project.budgetLines.isEmpty {
            result.append(
                ProjectInsight(
                    id: "no-budget-lines",
                    title: "Budget vide",
                    message: "Ajoutez vos premières lignes budgétaires pour estimer le coût réel.",
                    symbolName: "list.bullet.rectangle.portrait",
                    section: .budget
                )
            )
        }

        if project.locations.isEmpty {
            result.append(
                ProjectInsight(
                    id: "no-location",
                    title: "Aucun lieu",
                    message: "Rattachez des lieux de votre bibliothèque à ce projet.",
                    symbolName: "mappin.and.ellipse",
                    section: .locations
                )
            )
        }

        if project.peopleAssignments.isEmpty {
            result.append(
                ProjectInsight(
                    id: "no-crew",
                    title: "Aucune équipe",
                    message: "Constituez votre équipe à partir de la bibliothèque de personnes.",
                    symbolName: "person.badge.plus",
                    section: .people
                )
            )
        }

        if project.synopsis.isBlank {
            result.append(
                ProjectInsight(
                    id: "no-synopsis",
                    title: "Aucun synopsis",
                    message: "Résumez votre intention en quelques lignes, c'est la base de tout le reste.",
                    symbolName: "text.alignleft",
                    section: .overview
                )
            )
        }

        return result
    }
}
