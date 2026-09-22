import Foundation
import SwiftData

/// Root aggregate of the app: everything a production is made of hangs off a `Project`.
///
/// Children that only make sense inside a project (scenes, budget lines, shoot
/// days, references, assignments) are owned with a cascade delete rule. Library
/// entities (people, locations, equipment) are *referenced*, never owned, so
/// deleting a project never removes them from the global library.
@Model
final class Project {
    var id: UUID = UUID()
    var name: String = ""
    var type: ProjectType = ProjectType.blank
    var status: ProjectStatus = ProjectStatus.idea
    var createdAt: Date = Date()
    var updatedAt: Date = Date()
    var synopsis: String = ""
    var notes: String = ""
    var targetBudget: Decimal?
    /// Relative path of the cover image inside the app's media folder.
    /// Binary data is deliberately kept out of the store, see `MediaStore`.
    var coverImagePath: String?
    var isFavorite: Bool = false

    // MARK: Owned children

    @Relationship(deleteRule: .cascade, inverse: \StoryScene.project)
    var scenes: [StoryScene] = []

    @Relationship(deleteRule: .cascade, inverse: \BudgetLine.project)
    var budgetLines: [BudgetLine] = []

    @Relationship(deleteRule: .cascade, inverse: \ShootDay.project)
    var shootDays: [ShootDay] = []

    @Relationship(deleteRule: .cascade, inverse: \ReferenceAsset.project)
    var references: [ReferenceAsset] = []

    @Relationship(deleteRule: .cascade, inverse: \ProjectPersonAssignment.project)
    var peopleAssignments: [ProjectPersonAssignment] = []

    @Relationship(deleteRule: .cascade, inverse: \ProjectEquipmentAssignment.project)
    var equipmentAssignments: [ProjectEquipmentAssignment] = []

    // MARK: Library references

    /// Locations borrowed from the global library. Nullify on delete: removing a
    /// project must never delete a location that other projects still use.
    @Relationship(deleteRule: .nullify, inverse: \ProductionLocation.projects)
    var locations: [ProductionLocation] = []

    init(
        name: String = "",
        type: ProjectType = .blank,
        status: ProjectStatus = .idea,
        synopsis: String = "",
        notes: String = "",
        targetBudget: Decimal? = nil,
        coverImagePath: String? = nil,
        isFavorite: Bool = false,
        createdAt: Date = .now
    ) {
        self.id = UUID()
        self.name = name
        self.type = type
        self.status = status
        self.synopsis = synopsis
        self.notes = notes
        self.targetBudget = targetBudget
        self.coverImagePath = coverImagePath
        self.isFavorite = isFavorite
        self.createdAt = createdAt
        self.updatedAt = createdAt
    }
}

// MARK: - Derived values

extension Project {
    /// Name to render when the user has not typed one yet.
    var displayName: String {
        name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
            ? "Projet sans titre"
            : name
    }

    var sortedScenes: [StoryScene] {
        scenes.sorted { lhs, rhs in
            if lhs.orderIndex != rhs.orderIndex { return lhs.orderIndex < rhs.orderIndex }
            return lhs.createdAt < rhs.createdAt
        }
    }

    var sortedShootDays: [ShootDay] {
        shootDays.sorted { $0.date < $1.date }
    }

    var sortedReferences: [ReferenceAsset] {
        references.sorted { $0.createdAt > $1.createdAt }
    }

    /// Every shot of the project, in scene order then shot order.
    var allShots: [Shot] {
        sortedScenes.flatMap(\.sortedShots)
    }

    /// People attached to the project through their assignment, de-duplicated.
    var people: [Person] {
        var seen = Set<UUID>()
        var result: [Person] = []
        for assignment in sortedPeopleAssignments {
            guard let person = assignment.person, seen.insert(person.id).inserted else { continue }
            result.append(person)
        }
        return result
    }

    var sortedPeopleAssignments: [ProjectPersonAssignment] {
        peopleAssignments.sorted { lhs, rhs in
            let left = lhs.effectiveRole.department.sortIndex
            let right = rhs.effectiveRole.department.sortIndex
            if left != right { return left < right }
            return lhs.personDisplayName.localizedCaseInsensitiveCompare(rhs.personDisplayName) == .orderedAscending
        }
    }

    var sortedEquipmentAssignments: [ProjectEquipmentAssignment] {
        equipmentAssignments.sorted { lhs, rhs in
            let left = lhs.equipment?.category.sortIndex ?? Int.max
            let right = rhs.equipment?.category.sortIndex ?? Int.max
            if left != right { return left < right }
            return lhs.equipmentDisplayName.localizedCaseInsensitiveCompare(rhs.equipmentDisplayName) == .orderedAscending
        }
    }

    var sortedLocations: [ProductionLocation] {
        locations.sorted { $0.name.localizedCaseInsensitiveCompare($1.name) == .orderedAscending }
    }

    /// Shots already marked as shot, over the shots that still count (cancelled excluded).
    var shotProgress: (completed: Int, total: Int) {
        let relevant = allShots.filter { $0.status.countsInProgress }
        let completed = relevant.filter { $0.status.countsAsCompleted }.count
        return (completed, relevant.count)
    }

    /// The next shoot day from today, used by the overview header.
    var nextShootDay: ShootDay? {
        let startOfToday = Calendar.current.startOfDay(for: .now)
        return sortedShootDays.first { $0.date >= startOfToday }
    }

    func touch(_ date: Date = .now) {
        updatedAt = date
    }
}
