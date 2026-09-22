import Foundation
import SwiftData

/// Places the sections of a clip on the track, and owns the markers.
///
/// There is exactly one copy of a section's timing, on `MusicVideoFacet`, and
/// it is the one the writing editor already edits. The timeline moves the same
/// numbers; nothing here keeps a second version of the truth.
enum MusicTimelineService {
    /// Below this, a section is a marker, not a section.
    static let minimumSectionLength: TimeInterval = 0.25

    // MARK: Pure clamping

    /// Where a boundary between two adjacent sections is allowed to land.
    static func clampedBoundary(
        requested: TimeInterval,
        previousStart: TimeInterval?,
        nextEnd: TimeInterval?,
        duration: TimeInterval
    ) -> TimeInterval {
        var lower: TimeInterval = 0
        var upper = duration > 0 ? duration : max(requested, 0)

        if let previousStart { lower = max(lower, previousStart + minimumSectionLength) }
        if let nextEnd { upper = min(upper, nextEnd - minimumSectionLength) }

        guard upper >= lower else { return inTrack(lower, duration: duration) }
        return inTrack(min(max(requested, lower), upper), duration: duration)
    }

    /// Where a section's start is allowed to land, given its own end and the
    /// section before it.
    static func clampedStart(
        requested: TimeInterval,
        currentEnd: TimeInterval?,
        previousEnd: TimeInterval?,
        duration: TimeInterval
    ) -> TimeInterval {
        var lower: TimeInterval = 0
        var upper = duration > 0 ? duration : max(requested, 0)

        if let previousEnd { lower = max(lower, previousEnd) }
        if let currentEnd { upper = min(upper, currentEnd - minimumSectionLength) }

        guard upper >= lower else { return inTrack(lower, duration: duration) }
        return inTrack(min(max(requested, lower), upper), duration: duration)
    }

    /// Where a section's end is allowed to land.
    static func clampedEnd(
        requested: TimeInterval,
        currentStart: TimeInterval?,
        nextStart: TimeInterval?,
        duration: TimeInterval
    ) -> TimeInterval {
        var lower: TimeInterval = 0
        var upper = duration > 0 ? duration : max(requested, 0)

        if let currentStart { lower = max(lower, currentStart + minimumSectionLength) }
        if let nextStart { upper = min(upper, nextStart) }

        guard upper >= lower else { return inTrack(lower, duration: duration) }
        return inTrack(min(max(requested, lower), upper), duration: duration)
    }

    private static func inTrack(_ time: TimeInterval, duration: TimeInterval) -> TimeInterval {
        guard duration > 0 else { return max(time, 0) }
        return min(max(time, 0), duration)
    }

    // MARK: Reading the track

    /// The section covering a moment of the track, if any.
    static func section(at time: TimeInterval, in project: Project) -> StoryScene? {
        project.timedSections.last { scene in
            guard let start = scene.musicFacet?.startTime else { return false }
            let end = scene.musicFacet?.endTime ?? .greatestFiniteMagnitude
            return time >= start && time < end
        }
    }

    static func neighbours(of scene: StoryScene, in project: Project) -> (previous: StoryScene?, next: StoryScene?) {
        let ordered = project.timedSections
        guard let index = ordered.firstIndex(where: { $0.id == scene.id }) else { return (nil, nil) }
        let previous = index > 0 ? ordered[index - 1] : nil
        let next = index + 1 < ordered.count ? ordered[index + 1] : nil
        return (previous, next)
    }

    /// Every time worth snapping to, minus the one being dragged.
    static func snapCandidates(
        for project: Project,
        playhead: TimeInterval?,
        excludingSceneID excluded: UUID? = nil
    ) -> [TimeInterval] {
        var times: [TimeInterval] = [0]
        let duration = project.timelineDuration
        if duration > 0 { times.append(duration) }

        for scene in project.timedSections where scene.id != excluded {
            if let start = scene.musicFacet?.startTime { times.append(start) }
            if let end = scene.musicFacet?.endTime { times.append(end) }
        }
        times.append(contentsOf: project.markers.map(\.time))
        if let playhead { times.append(playhead) }
        return times
    }

    // MARK: Sections

    /// Adds a section starting at a moment of the track.
    ///
    /// Dropping one inside an existing section splits it there, which is what
    /// "add a section at the playhead" means on a linear timeline.
    @discardableResult
    static func createSection(
        at time: TimeInterval,
        kind: MusicSectionKind? = nil,
        in project: Project,
        context: ModelContext
    ) -> StoryScene {
        let duration = project.timelineDuration
        let start = inTrack(time, duration: max(duration - minimumSectionLength, 0))

        let containing = section(at: start, in: project)
        let nextStart = project.timedSections
            .compactMap { $0.musicFacet?.startTime }
            .filter { $0 > start }
            .min()

        var end = containing?.musicFacet?.endTime ?? nextStart ?? duration
        if end <= start + minimumSectionLength {
            end = duration > start ? duration : start + minimumSectionLength
        }

        let scene = MusicVideoService.createSection(in: project, kind: kind, context: context)
        let facet = MusicVideoService.facet(for: scene, context: context)
        facet.startTime = start
        facet.endTime = max(end, start + minimumSectionLength)

        if let containing, containing.id != scene.id {
            containing.musicFacet?.endTime = start
        }

        resequenceByTime(project)
        project.touch()
        PersistenceActions.save(context)
        return scene
    }

    /// Moves the frontier shared by two adjacent sections.
    static func setBoundary(
        between previous: StoryScene?,
        and next: StoryScene?,
        to requested: TimeInterval,
        in project: Project,
        context: ModelContext
    ) {
        let time = clampedBoundary(
            requested: requested,
            previousStart: previous?.musicFacet?.startTime,
            nextEnd: next?.musicFacet?.endTime,
            duration: project.timelineDuration
        )
        previous?.musicFacet?.endTime = time
        next?.musicFacet?.startTime = time

        previous?.musicFacet?.touch()
        next?.musicFacet?.touch()
        resequenceByTime(project)
        project.touch()
        PersistenceActions.save(context)
    }

    static func setStart(_ requested: TimeInterval, for scene: StoryScene, in project: Project, context: ModelContext) {
        guard let facet = scene.musicFacet else { return }
        let siblings = neighbours(of: scene, in: project)
        facet.startTime = clampedStart(
            requested: requested,
            currentEnd: facet.endTime,
            previousEnd: siblings.previous?.musicFacet?.endTime,
            duration: project.timelineDuration
        )
        facet.touch()
        resequenceByTime(project)
        PersistenceActions.save(context)
    }

    static func setEnd(_ requested: TimeInterval, for scene: StoryScene, in project: Project, context: ModelContext) {
        guard let facet = scene.musicFacet else { return }
        let siblings = neighbours(of: scene, in: project)
        facet.endTime = clampedEnd(
            requested: requested,
            currentStart: facet.startTime,
            nextStart: siblings.next?.musicFacet?.startTime,
            duration: project.timelineDuration
        )
        facet.touch()
        resequenceByTime(project)
        PersistenceActions.save(context)
    }

    /// Positions a section that had no timing yet, at the playhead.
    static func placeOnTrack(_ scene: StoryScene, at time: TimeInterval, in project: Project, context: ModelContext) {
        let facet = MusicVideoService.facet(for: scene, context: context)
        let duration = project.timelineDuration
        let start = inTrack(time, duration: max(duration - minimumSectionLength, 0))
        let nextStart = project.timedSections
            .compactMap { $0.musicFacet?.startTime }
            .filter { $0 > start }
            .min()
        facet.startTime = start
        facet.endTime = max(nextStart ?? duration, start + minimumSectionLength)
        facet.touch()
        resequenceByTime(project)
        PersistenceActions.save(context)
    }

    /// Pulls everything back inside the track, after a shorter one replaces it.
    /// Nothing is ever deleted: a section that no longer fits is shortened.
    static func clampToDuration(_ project: Project, context: ModelContext) {
        let duration = project.timelineDuration
        guard duration > 0 else { return }

        for scene in project.musicSections {
            guard let facet = scene.musicFacet else { continue }
            if let start = facet.startTime {
                facet.startTime = inTrack(start, duration: duration)
            }
            if let end = facet.endTime {
                facet.endTime = inTrack(end, duration: duration)
            }
            if let start = facet.startTime, let end = facet.endTime, end < start {
                facet.endTime = start
            }
        }
        for marker in project.markers {
            marker.time = inTrack(marker.time, duration: duration)
        }
        resequenceByTime(project)
        project.touch()
        PersistenceActions.save(context)
    }

    /// Keeps the scene order in step with the track order, so the writing
    /// editor and the timeline always read the same sequence.
    static func resequenceByTime(_ project: Project) {
        let timed = project.musicSections
            .filter { $0.musicFacet?.startTime != nil }
            .sorted { lhs, rhs in
                let left = lhs.musicFacet?.startTime ?? 0
                let right = rhs.musicFacet?.startTime ?? 0
                if left != right { return left < right }
                return lhs.createdAt < rhs.createdAt
            }
        let untimed = project.musicSections
            .filter { $0.musicFacet?.startTime == nil }
            .sorted { $0.orderIndex < $1.orderIndex }
        let others = project.sortedScenes.filter { $0.musicFacet == nil }

        for (index, scene) in (timed + untimed + others).enumerated() where scene.orderIndex != index {
            scene.orderIndex = index
        }
    }

    // MARK: Markers

    @discardableResult
    static func addMarker(
        at time: TimeInterval,
        title: String = "",
        type: TimelineMarkerType = .standard,
        in project: Project,
        context: ModelContext
    ) -> TimelineMarker {
        let marker = TimelineMarker(
            time: inTrack(time, duration: project.timelineDuration),
            title: title,
            type: type
        )
        marker.project = project
        context.insert(marker)
        project.touch()
        PersistenceActions.save(context)
        return marker
    }

    static func move(_ marker: TimelineMarker, to time: TimeInterval, in project: Project, context: ModelContext) {
        marker.time = inTrack(time, duration: project.timelineDuration)
        marker.touch()
        PersistenceActions.save(context)
    }

    static func delete(_ marker: TimelineMarker, context: ModelContext) {
        let project = marker.project
        project?.markers.removeAll { $0.id == marker.id }
        context.delete(marker)
        project?.touch()
        PersistenceActions.save(context)
    }

    static func commitEdits(to marker: TimelineMarker, in project: Project, context: ModelContext) {
        marker.time = inTrack(marker.time, duration: project.timelineDuration)
        marker.touch()
        PersistenceActions.save(context)
    }
}
