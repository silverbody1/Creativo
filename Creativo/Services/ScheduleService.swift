import Foundation
import SwiftData

/// Creation and deletion of shooting days.
///
/// Phase 1 keeps the schedule to a plain, ordered list. The relationships to
/// scenes and people already exist on `ShootDay`, so the calendar phase only
/// has to add views.
enum ScheduleService {
    @discardableResult
    static func createDay(
        in project: Project,
        date: Date = .now,
        title: String = "",
        context: ModelContext
    ) -> ShootDay {
        let day = ShootDay(
            date: Calendar.current.startOfDay(for: date),
            title: title.isBlank ? defaultTitle(for: project) : title,
            callTime: defaultCallTime(on: date),
            estimatedWrapTime: defaultWrapTime(on: date)
        )
        day.project = project
        context.insert(day)
        project.touch()
        PersistenceActions.save(context)
        return day
    }

    static func delete(_ day: ShootDay, context: ModelContext) {
        let project = day.project
        context.delete(day)
        project?.touch()
        PersistenceActions.save(context)
    }

    static func commitEdits(to day: ShootDay, context: ModelContext) {
        day.date = Calendar.current.startOfDay(for: day.date)
        day.touch()
        PersistenceActions.save(context)
    }

    /// `Jour 3` — numbered from the days already planned.
    static func defaultTitle(for project: Project) -> String {
        "Jour \(project.shootDays.count + 1)"
    }

    private static func defaultCallTime(on date: Date) -> Date {
        Calendar.current.date(
            bySettingHour: 8, minute: 0, second: 0,
            of: Calendar.current.startOfDay(for: date)
        ) ?? date
    }

    private static func defaultWrapTime(on date: Date) -> Date {
        Calendar.current.date(
            bySettingHour: 19, minute: 0, second: 0,
            of: Calendar.current.startOfDay(for: date)
        ) ?? date
    }
}
