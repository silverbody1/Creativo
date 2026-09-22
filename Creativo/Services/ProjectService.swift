import Foundation
import SwiftData

/// Creation, update and deletion of projects.
///
/// Views never touch the `ModelContext` directly for these operations: keeping
/// them here is what makes the rules testable and keeps `updatedAt` honest.
enum ProjectService {
    @discardableResult
    static func create(
        name: String,
        type: ProjectType,
        targetBudget: Decimal? = nil,
        status: ProjectStatus = .idea,
        synopsis: String = "",
        in context: ModelContext
    ) -> Project {
        let trimmedName = name.trimmed
        let project = Project(
            name: trimmedName.isEmpty ? defaultName(for: type) : trimmedName,
            type: type,
            status: status,
            synopsis: synopsis,
            targetBudget: targetBudget
        )
        context.insert(project)
        PersistenceActions.save(context)
        return project
    }

    /// Deletes a project and everything it owns.
    ///
    /// Library entities are untouched: SwiftData nullifies the link and the
    /// person, location or equipment stays available for other productions.
    static func delete(_ project: Project, in context: ModelContext) {
        if let coverPath = project.coverImagePath {
            MediaStore.shared.removeFile(relativePath: coverPath)
        }
        for reference in project.references {
            if let path = reference.localPath {
                MediaStore.shared.removeFile(relativePath: path)
            }
        }
        context.delete(project)
        PersistenceActions.save(context)
    }

    static func toggleFavorite(_ project: Project, in context: ModelContext) {
        project.isFavorite.toggle()
        project.touch()
        PersistenceActions.save(context)
    }

    static func setStatus(_ status: ProjectStatus, on project: Project, in context: ModelContext) {
        guard project.status != status else { return }
        project.status = status
        project.touch()
        PersistenceActions.save(context)
    }

    /// Records an edit made through a form and stamps the modification date.
    static func commitEdits(to project: Project, in context: ModelContext) {
        project.touch()
        PersistenceActions.save(context)
    }

    /// Name proposed when the user creates a project without typing one.
    static func defaultName(for type: ProjectType) -> String {
        switch type {
        case .musicVideo: return "Nouveau clip"
        case .youtube: return "Nouvelle vidéo"
        case .film: return "Nouveau film"
        case .commercial: return "Nouvelle publicité"
        case .social: return "Nouveau contenu social"
        case .blank: return "Nouveau projet"
        }
    }

    /// Projects sorted the way the app always shows them: most recently touched first.
    static func sortedByRecency(_ projects: [Project]) -> [Project] {
        projects.sorted { $0.updatedAt > $1.updatedAt }
    }

    static func filter(_ projects: [Project], query: String) -> [Project] {
        guard !query.isBlank else { return projects }
        return projects.filter { project in
            project.name.matches(query)
                || project.synopsis.matches(query)
                || project.type.displayName.matches(query)
                || project.status.displayName.matches(query)
        }
    }
}
