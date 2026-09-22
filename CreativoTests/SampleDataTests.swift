import XCTest
import SwiftData
@testable import Creativo

/// The sample data is used by every preview, so a broken fixture breaks the
/// whole design workflow. These tests keep it honest.
final class SampleDataTests: CreativoTestCase {
    func testPopulateCreatesACompleteProduction() throws {
        let project = SampleData.populate(context)

        XCTAssertEqual(project.name, "PARTENAIRE")
        XCTAssertEqual(project.type, .musicVideo)
        XCTAssertEqual(project.status, .preProduction)
        XCTAssertEqual(
            project.sortedScenes.map(\.title),
            ["Intro", "Couplet 1", "Refrain 1", "Couplet 2", "Refrain 2", "Outro"]
        )
        XCTAssertFalse(project.allShots.isEmpty)
        XCTAssertFalse(project.budgetLines.isEmpty)
        XCTAssertFalse(project.peopleAssignments.isEmpty)
        XCTAssertFalse(project.equipmentAssignments.isEmpty)
        XCTAssertEqual(project.shootDays.count, 2)
        XCTAssertEqual(project.locations.count, 2)
    }

    func testPopulateCreatesSharedLibraryEntities() throws {
        SampleData.populate(context)

        XCTAssertGreaterThanOrEqual(try countOf(Person.self), 5)
        XCTAssertGreaterThanOrEqual(try countOf(ProductionLocation.self), 3)
        XCTAssertGreaterThanOrEqual(try countOf(EquipmentItem.self), 5)

        // One project per writing surface: clip, screenplay, video script.
        let projects = try fetchAll(Project.self)
        XCTAssertEqual(projects.count, 3)
        XCTAssertEqual(Set(projects.map(\.type)), [.musicVideo, .film, .youtube])
    }

    func testSampleClipIsPlacedOnATimelineWithoutNeedingAnAudioFile() throws {
        let project = SampleData.populate(context)

        // Every section carries a timecode, in order, with no gap or overlap.
        let sections = project.timedSections
        XCTAssertEqual(sections.count, project.musicSections.count)
        XCTAssertEqual(sections.first?.musicFacet?.startTime, 0)

        for (index, scene) in sections.enumerated() {
            let facet = try XCTUnwrap(scene.musicFacet)
            let start = try XCTUnwrap(facet.startTime)
            let end = try XCTUnwrap(facet.endTime)
            XCTAssertGreaterThan(end, start, "\(scene.title) a une durée nulle ou négative")
            if index > 0 {
                let previousEnd = try XCTUnwrap(sections[index - 1].musicFacet?.endTime)
                XCTAssertEqual(start, previousEnd, accuracy: 0.001)
            }
        }

        // The timeline works with no audio: the sections give it its length.
        XCTAssertNil(project.primaryAudioAsset)
        XCTAssertGreaterThan(project.timelineDuration, 0)
        XCTAssertEqual(project.timelineDuration, sections.last?.musicFacet?.endTime)
    }

    func testSampleClipCarriesMarkersOfSeveralKinds() throws {
        let project = SampleData.populate(context)

        XCTAssertGreaterThanOrEqual(project.markers.count, 4)
        XCTAssertEqual(project.sortedMarkers.map(\.time), project.sortedMarkers.map(\.time).sorted())
        XCTAssertGreaterThanOrEqual(Set(project.markers.map(\.type)).count, 3)
        XCTAssertTrue(project.markers.allSatisfy { $0.time <= project.timelineDuration })
        XCTAssertTrue(project.markers.allSatisfy { !$0.displayTitle.isEmpty })
    }

    func testTheTimelineSectionOnlyExistsForClips() {
        XCTAssertTrue(ProjectType.musicVideo.hasAudioTimeline)
        XCTAssertFalse(ProjectType.film.hasAudioTimeline)
        XCTAssertTrue(WorkspaceSection.creationGroup(for: .musicVideo).contains(.timeline))
        XCTAssertFalse(WorkspaceSection.creationGroup(for: .film).contains(.timeline))
        XCTAssertTrue(WorkspaceSection.isAvailable(.timeline, for: .musicVideo))
        XCTAssertFalse(WorkspaceSection.isAvailable(.timeline, for: .youtube))
        XCTAssertTrue(WorkspaceSection.isAvailable(.scenes, for: .film))
    }

    func testSampleBudgetProducesACoherentSummary() throws {
        let project = SampleData.populate(context)
        let summary = project.budgetSummary

        XCTAssertEqual(summary.target, 12_000)
        XCTAssertGreaterThan(summary.forecast, 0)
        XCTAssertGreaterThan(summary.spent, 0)
        XCTAssertNotNil(summary.forecastRatio)
    }

    func testEmptyProjectSurfacesEveryPreparationGap() throws {
        let project = ProjectService.create(name: "Vide", type: .blank, context: context)
        let ids = Set(ProjectInsights.insights(for: project).map(\.id))

        XCTAssertTrue(ids.contains("no-scenes"))
        XCTAssertTrue(ids.contains("no-shoot-day"))
        XCTAssertTrue(ids.contains("no-target-budget"))
        XCTAssertTrue(ids.contains("no-location"))
        XCTAssertTrue(ids.contains("no-crew"))
        XCTAssertTrue(ids.contains("no-synopsis"))
    }

    func testSampleProjectHasFewerGapsThanAnEmptyOne() throws {
        let sample = SampleData.populate(context)
        let empty = ProjectService.create(name: "Vide", type: .blank, context: context)

        let sampleGaps = ProjectInsights.insights(for: sample).count
        let emptyGaps = ProjectInsights.insights(for: empty).count

        XCTAssertLessThan(sampleGaps, emptyGaps)
    }
}
