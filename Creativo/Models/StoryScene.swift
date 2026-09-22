import Foundation
import SwiftData

/// A scene of a project.
///
/// Named `StoryScene` rather than `Scene` on purpose: `Scene` is a SwiftUI
/// protocol and shadowing it inside an app target makes every `App` body
/// ambiguous. The user-facing wording stays "scène" everywhere.
@Model
final class StoryScene {
    var id: UUID = UUID()
    /// Free-form so that inserted scenes can be numbered "12A" the way a
    /// screenplay would. Ordering is driven by `orderIndex`, never by this.
    var sceneNumber: String = ""
    var title: String = ""
    var synopsis: String = ""
    var content: String = ""
    var environment: SceneEnvironment = SceneEnvironment.interior
    var timeOfDay: TimeOfDay = TimeOfDay.day
    /// Estimated screen time, in seconds.
    var estimatedDuration: TimeInterval = 0
    var status: SceneStatus = SceneStatus.draft
    var orderIndex: Int = 0
    var notes: String = ""
    var createdAt: Date = Date()
    var updatedAt: Date = Date()

    var project: Project?

    @Relationship(deleteRule: .cascade, inverse: \Shot.scene)
    var shots: [Shot] = []

    /// Borrowed from the global library, so nullify rather than cascade.
    var location: ProductionLocation?

    /// Shooting days this scene is scheduled on. Populated by the scheduling
    /// phase; declared now so the relationship never has to be migrated in.
    var shootDays: [ShootDay] = []

    // MARK: Writing facets

    /// Typed screenplay lines. Empty for a project written in another mode.
    @Relationship(deleteRule: .cascade, inverse: \ScreenplayElement.scene)
    var screenplayElements: [ScreenplayElement] = []

    /// Music-video specifics. Present only on the scenes of a clip, where the
    /// scene doubles as a section of the song.
    @Relationship(deleteRule: .cascade, inverse: \MusicVideoFacet.scene)
    var musicFacet: MusicVideoFacet?

    init(
        sceneNumber: String = "",
        title: String = "",
        synopsis: String = "",
        content: String = "",
        environment: SceneEnvironment = .interior,
        timeOfDay: TimeOfDay = .day,
        estimatedDuration: TimeInterval = 0,
        status: SceneStatus = .draft,
        orderIndex: Int = 0,
        notes: String = "",
        createdAt: Date = .now
    ) {
        self.id = UUID()
        self.sceneNumber = sceneNumber
        self.title = title
        self.synopsis = synopsis
        self.content = content
        self.environment = environment
        self.timeOfDay = timeOfDay
        self.estimatedDuration = estimatedDuration
        self.status = status
        self.orderIndex = orderIndex
        self.notes = notes
        self.createdAt = createdAt
        self.updatedAt = createdAt
    }
}

extension StoryScene {
    var displayTitle: String {
        title.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
            ? "Scène sans titre"
            : title
    }

    /// Number to show in lists, falling back to the position when empty.
    var displayNumber: String {
        let trimmed = sceneNumber.trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmed.isEmpty ? "\(orderIndex + 1)" : trimmed
    }

    /// Screenplay-style slug line, e.g. `INT. STUDIO — NUIT`.
    var slugline: String {
        let place = location?.name.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        let head = place.isEmpty ? displayTitle : place
        return "\(environment.abbreviation) \(head.uppercased()) — \(timeOfDay.displayName.uppercased())"
    }

    var sortedScreenplayElements: [ScreenplayElement] {
        screenplayElements.sorted { lhs, rhs in
            if lhs.orderIndex != rhs.orderIndex { return lhs.orderIndex < rhs.orderIndex }
            return lhs.createdAt < rhs.createdAt
        }
    }

    /// `true` once the scene has been written in the screenplay editor.
    var hasScreenplay: Bool { !screenplayElements.isEmpty }

    /// Name shown in the clip editor: the section, then the scene title.
    var musicSectionName: String {
        guard let facet = musicFacet else { return displayTitle }
        return title.isBlank ? facet.displayName : "\(facet.displayName) · \(title)"
    }

    var sortedShots: [Shot] {
        shots.sorted { lhs, rhs in
            if lhs.orderIndex != rhs.orderIndex { return lhs.orderIndex < rhs.orderIndex }
            return lhs.createdAt < rhs.createdAt
        }
    }

    var shotProgress: (completed: Int, total: Int) {
        let relevant = shots.filter { $0.status.countsInProgress }
        return (relevant.filter { $0.status.countsAsCompleted }.count, relevant.count)
    }

    func touch(_ date: Date = .now) {
        updatedAt = date
        project?.touch(date)
    }
}
