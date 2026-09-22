import Foundation
import SwiftData

/// One day of shooting on a project.
///
/// Call time and wrap time are stored as full `Date` values on the shoot day
/// itself so that a night shoot wrapping after midnight stays representable.
@Model
final class ShootDay {
    var id: UUID = UUID()
    var date: Date = Date()
    var title: String = ""
    var callTime: Date?
    var estimatedWrapTime: Date?
    var notes: String = ""
    var createdAt: Date = Date()
    var updatedAt: Date = Date()

    var project: Project?

    /// Scenes planned for this day. Inverse of `StoryScene.shootDays`.
    @Relationship(deleteRule: .nullify, inverse: \StoryScene.shootDays)
    var scenes: [StoryScene] = []

    /// People called on this day. Inverse of `Person.shootDays`.
    @Relationship(deleteRule: .nullify, inverse: \Person.shootDays)
    var people: [Person] = []

    init(
        date: Date = .now,
        title: String = "",
        callTime: Date? = nil,
        estimatedWrapTime: Date? = nil,
        notes: String = "",
        createdAt: Date = .now
    ) {
        self.id = UUID()
        self.date = date
        self.title = title
        self.callTime = callTime
        self.estimatedWrapTime = estimatedWrapTime
        self.notes = notes
        self.createdAt = createdAt
        self.updatedAt = createdAt
    }
}

extension ShootDay {
    var displayTitle: String {
        title.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
            ? "Journée de tournage"
            : title
    }

    /// Planned duration, when both call time and wrap time are known.
    var plannedDuration: TimeInterval? {
        guard let callTime, let estimatedWrapTime, estimatedWrapTime > callTime else { return nil }
        return estimatedWrapTime.timeIntervalSince(callTime)
    }

    var isPast: Bool {
        date < Calendar.current.startOfDay(for: .now)
    }

    var isToday: Bool {
        Calendar.current.isDateInToday(date)
    }

    func touch(_ date: Date = .now) {
        updatedAt = date
        project?.touch(date)
    }
}
