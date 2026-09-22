import XCTest
import SwiftData
@testable import Creativo

final class MusicTimelineTests: CreativoTestCase {
    /// A clip whose track length is **stated**, not inferred.
    ///
    /// The asset carries no file — these tests never play anything — but it
    /// pins the duration, so a test about section chaining cannot accidentally
    /// become a test about the fallback length.
    private func makeClip(duration: TimeInterval = 240) -> Project {
        let project = ProjectService.create(name: "PARTENAIRE", type: .musicVideo, context: context)

        let asset = ProjectMediaAsset(type: .audio, displayName: "master", duration: duration)
        asset.project = project
        context.insert(asset)
        project.primaryAudioAssetID = asset.id

        let intro = MusicVideoService.createSection(in: project, kind: .intro, context: context)
        intro.musicFacet?.startTime = 0
        intro.musicFacet?.endTime = duration
        MusicTimelineService.resequenceByTime(project)
        return project
    }

    // MARK: Pure clamping

    func testBoundaryCannotCrossTheSectionBeforeIt() {
        let time = MusicTimelineService.clampedBoundary(
            requested: 5,
            previousStart: 20,
            nextEnd: 120,
            duration: 200
        )
        XCTAssertEqual(time, 20 + MusicTimelineService.minimumSectionLength)
    }

    func testBoundaryCannotCrossTheSectionAfterIt() {
        let time = MusicTimelineService.clampedBoundary(
            requested: 190,
            previousStart: 20,
            nextEnd: 120,
            duration: 200
        )
        XCTAssertEqual(time, 120 - MusicTimelineService.minimumSectionLength)
    }

    func testBoundaryStaysInsideTheTrack() {
        XCTAssertEqual(
            MusicTimelineService.clampedBoundary(requested: -50, previousStart: nil, nextEnd: nil, duration: 200),
            0
        )
        XCTAssertEqual(
            MusicTimelineService.clampedBoundary(requested: 900, previousStart: nil, nextEnd: nil, duration: 200),
            200
        )
    }

    func testBoundaryNeverProducesANegativeDuration() {
        // Two sections so short that no legal position exists: the result is
        // still a valid time inside the track, never an inverted one.
        let time = MusicTimelineService.clampedBoundary(
            requested: 50,
            previousStart: 49.9,
            nextEnd: 50.0,
            duration: 200
        )
        XCTAssertGreaterThanOrEqual(time, 0)
        XCTAssertLessThanOrEqual(time, 200)
    }

    func testStartIsClampedBetweenTheNeighbourAndItsOwnEnd() {
        XCTAssertEqual(
            MusicTimelineService.clampedStart(requested: 5, currentEnd: 60, previousEnd: 30, duration: 200),
            30
        )
        XCTAssertEqual(
            MusicTimelineService.clampedStart(requested: 100, currentEnd: 60, previousEnd: 30, duration: 200),
            60 - MusicTimelineService.minimumSectionLength
        )
    }

    func testEndIsClampedBetweenItsOwnStartAndTheNextSection() {
        XCTAssertEqual(
            MusicTimelineService.clampedEnd(requested: 10, currentStart: 30, nextStart: 90, duration: 200),
            30 + MusicTimelineService.minimumSectionLength
        )
        XCTAssertEqual(
            MusicTimelineService.clampedEnd(requested: 150, currentStart: 30, nextStart: 90, duration: 200),
            90
        )
    }

    // MARK: Creating sections

    func testAddingASectionAtThePlayheadSplitsTheOneItLandsIn() throws {
        let project = makeClip(duration: 240)
        let intro = try XCTUnwrap(project.timedSections.first)

        let verse = MusicTimelineService.createSection(at: 60, kind: .verse, in: project, context: context)

        XCTAssertEqual(intro.musicFacet?.endTime, 60)
        XCTAssertEqual(verse.musicFacet?.startTime, 60)
        XCTAssertEqual(verse.musicFacet?.endTime, 240)
        XCTAssertEqual(project.timedSections.map(\.id), [intro.id, verse.id])
    }

    func testANewSectionRunsUntilTheNextOne() throws {
        let project = makeClip(duration: 240)
        let intro = try XCTUnwrap(project.timedSections.first)
        intro.musicFacet?.endTime = 30

        let chorus = MusicTimelineService.createSection(at: 120, kind: .chorus, in: project, context: context)
        let verse = MusicTimelineService.createSection(at: 60, kind: .verse, in: project, context: context)

        XCTAssertEqual(verse.musicFacet?.startTime, 60)
        XCTAssertEqual(verse.musicFacet?.endTime, chorus.musicFacet?.startTime)
    }

    func testSectionsStayInTimeOrder() throws {
        let project = makeClip(duration: 240)
        MusicTimelineService.createSection(at: 180, kind: .outro, in: project, context: context)
        MusicTimelineService.createSection(at: 60, kind: .verse, in: project, context: context)

        let starts = project.timedSections.compactMap { $0.musicFacet?.startTime }
        XCTAssertEqual(starts, starts.sorted())
        XCTAssertEqual(project.sortedScenes.map(\.orderIndex), Array(0..<project.scenes.count))
    }

    // MARK: Moving frontiers

    func testMovingAFrontierKeepsTwoAdjacentSectionsJoined() throws {
        let project = makeClip(duration: 240)
        let intro = try XCTUnwrap(project.timedSections.first)
        let verse = MusicTimelineService.createSection(at: 60, kind: .verse, in: project, context: context)

        MusicTimelineService.setBoundary(between: intro, and: verse, to: 45, in: project, context: context)

        XCTAssertEqual(intro.musicFacet?.endTime, 45)
        XCTAssertEqual(verse.musicFacet?.startTime, 45)
    }

    func testAFrontierDraggedTooFarIsHeldBack() throws {
        let project = makeClip(duration: 240)
        let intro = try XCTUnwrap(project.timedSections.first)
        let verse = MusicTimelineService.createSection(at: 60, kind: .verse, in: project, context: context)

        MusicTimelineService.setBoundary(between: intro, and: verse, to: 900, in: project, context: context)

        let end = try XCTUnwrap(intro.musicFacet?.endTime)
        XCTAssertLessThanOrEqual(end, 240)
        XCTAssertGreaterThan(try XCTUnwrap(verse.musicFacet?.endTime), end)
    }

    func testEditingTimecodesFromTheInspectorRespectsTheNeighbours() throws {
        let project = makeClip(duration: 240)
        let intro = try XCTUnwrap(project.timedSections.first)
        let verse = MusicTimelineService.createSection(at: 60, kind: .verse, in: project, context: context)

        MusicTimelineService.setStart(10, for: verse, in: project, context: context)
        XCTAssertEqual(verse.musicFacet?.startTime, intro.musicFacet?.endTime)

        MusicTimelineService.setEnd(5, for: verse, in: project, context: context)
        let start = try XCTUnwrap(verse.musicFacet?.startTime)
        XCTAssertEqual(verse.musicFacet?.endTime, start + MusicTimelineService.minimumSectionLength)
    }

    func testPlacingAnUntimedSectionOnTheTrack() throws {
        let project = makeClip(duration: 240)
        let floating = MusicVideoService.createSection(in: project, kind: .bridge, context: context)
        floating.musicFacet?.startTime = nil
        floating.musicFacet?.endTime = nil
        XCTAssertFalse(project.timedSections.contains { $0.id == floating.id })

        MusicTimelineService.placeOnTrack(floating, at: 100, in: project, context: context)

        XCTAssertEqual(floating.musicFacet?.startTime, 100)
        XCTAssertTrue(project.timedSections.contains { $0.id == floating.id })
    }

    // MARK: Reading the track

    func testSectionAtATimeFindsTheRightOne() throws {
        let project = makeClip(duration: 240)
        let intro = try XCTUnwrap(project.timedSections.first)
        let verse = MusicTimelineService.createSection(at: 60, kind: .verse, in: project, context: context)

        XCTAssertEqual(MusicTimelineService.section(at: 10, in: project)?.id, intro.id)
        XCTAssertEqual(MusicTimelineService.section(at: 60, in: project)?.id, verse.id)
        XCTAssertEqual(MusicTimelineService.section(at: 239, in: project)?.id, verse.id)
        XCTAssertNil(MusicTimelineService.section(at: 900, in: project))
    }

    func testNeighboursFollowTheTrackOrder() throws {
        let project = makeClip(duration: 240)
        let intro = try XCTUnwrap(project.timedSections.first)
        let verse = MusicTimelineService.createSection(at: 60, kind: .verse, in: project, context: context)
        let chorus = MusicTimelineService.createSection(at: 120, kind: .chorus, in: project, context: context)

        let around = MusicTimelineService.neighbours(of: verse, in: project)
        XCTAssertEqual(around.previous?.id, intro.id)
        XCTAssertEqual(around.next?.id, chorus.id)
        XCTAssertNil(MusicTimelineService.neighbours(of: intro, in: project).previous)
    }

    func testSnapCandidatesCoverEveryEdgeAndMarker() throws {
        let project = makeClip(duration: 240)
        MusicTimelineService.createSection(at: 60, kind: .verse, in: project, context: context)
        MusicTimelineService.addMarker(at: 91, title: "drop", type: .beat, in: project, context: context)

        let candidates = MusicTimelineService.snapCandidates(for: project, playhead: 17)
        XCTAssertTrue(candidates.contains(0))
        XCTAssertTrue(candidates.contains(60))
        XCTAssertTrue(candidates.contains(91))
        XCTAssertTrue(candidates.contains(17))
        XCTAssertTrue(candidates.contains(240))
    }

    // MARK: Markers

    func testMarkersBelongToTheProjectAndStayOrdered() throws {
        let project = makeClip(duration: 240)
        MusicTimelineService.addMarker(at: 120, title: "drop", type: .beat, in: project, context: context)
        let first = MusicTimelineService.addMarker(at: 12, title: "entrée", type: .camera, in: project, context: context)

        XCTAssertEqual(project.markers.count, 2)
        XCTAssertEqual(project.sortedMarkers.first?.id, first.id)
        XCTAssertEqual(first.project?.id, project.id)
        XCTAssertEqual(first.displayTitle, "entrée")
    }

    func testAMarkerIsClampedToTheTrack() throws {
        let project = makeClip(duration: 240)
        let marker = MusicTimelineService.addMarker(at: 9_000, in: project, context: context)
        XCTAssertEqual(marker.time, 240)

        MusicTimelineService.move(marker, to: -40, in: project, context: context)
        XCTAssertEqual(marker.time, 0)
    }

    func testDeletingAMarkerLeavesTheProjectIntact() throws {
        let project = makeClip(duration: 240)
        let marker = MusicTimelineService.addMarker(at: 30, in: project, context: context)

        MusicTimelineService.delete(marker, context: context)

        XCTAssertTrue(project.markers.isEmpty)
        XCTAssertEqual(try countOf(TimelineMarker.self), 0)
        XCTAssertEqual(try countOf(Project.self), 1)
    }

    func testDeletingTheProjectDeletesItsMarkers() throws {
        let project = makeClip(duration: 240)
        MusicTimelineService.addMarker(at: 30, in: project, context: context)
        MusicTimelineService.addMarker(at: 60, in: project, context: context)

        ProjectService.delete(project, context: context)

        XCTAssertEqual(try countOf(TimelineMarker.self), 0)
    }

    // MARK: A shorter track

    func testClampingPullsEverythingBackInsideAShorterTrackWithoutDeleting() throws {
        let project = makeClip(duration: 240)
        let intro = try XCTUnwrap(project.timedSections.first)
        let verse = MusicTimelineService.createSection(at: 120, kind: .verse, in: project, context: context)
        let marker = MusicTimelineService.addMarker(at: 200, in: project, context: context)

        // The track is replaced by a shorter one; sections must survive.
        let asset = ProjectMediaAsset(type: .audio, displayName: "court", duration: 90)
        asset.project = project
        context.insert(asset)
        project.primaryAudioAssetID = asset.id

        MusicTimelineService.clampToDuration(project, context: context)

        XCTAssertEqual(project.musicSections.count, 2)
        XCTAssertLessThanOrEqual(try XCTUnwrap(intro.musicFacet?.endTime), 90)
        XCTAssertLessThanOrEqual(try XCTUnwrap(verse.musicFacet?.endTime), 90)
        XCTAssertEqual(marker.time, 90)
        for scene in project.musicSections {
            let start = try XCTUnwrap(scene.musicFacet?.startTime)
            let end = try XCTUnwrap(scene.musicFacet?.endTime)
            XCTAssertGreaterThanOrEqual(end, start)
        }
    }

    // MARK: Length of the track

    func testAClipWithoutAudioStartsOnAUsableCanvas() throws {
        let project = ProjectService.create(name: "PARTENAIRE", type: .musicVideo, context: context)
        XCTAssertNil(project.primaryAudioAsset)
        XCTAssertEqual(project.timelineDuration, Project.fallbackTimelineDuration)
    }

    func testSectionsExtendTheCanvasButNeverShrinkIt() throws {
        let project = ProjectService.create(name: "PARTENAIRE", type: .musicVideo, context: context)
        let intro = MusicVideoService.createSection(in: project, kind: .intro, context: context)
        intro.musicFacet?.startTime = 0
        intro.musicFacet?.endTime = 300
        XCTAssertEqual(project.timelineDuration, 300)

        // Shortening a section must not shrink the timeline under it: there
        // would be nowhere left to drag the section back out to.
        intro.musicFacet?.endTime = 30
        XCTAssertEqual(project.timelineDuration, Project.fallbackTimelineDuration)
        XCTAssertGreaterThan(project.timelineDuration, 30)
    }

    func testImportedAudioDecidesTheLength() throws {
        let project = ProjectService.create(name: "PARTENAIRE", type: .musicVideo, context: context)
        let asset = ProjectMediaAsset(type: .audio, displayName: "master", duration: 42)
        asset.project = project
        context.insert(asset)
        project.primaryAudioAssetID = asset.id

        XCTAssertEqual(project.timelineDuration, 42)
    }
}
