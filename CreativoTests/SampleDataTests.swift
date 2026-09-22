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
        XCTAssertEqual(project.sortedScenes.map(\.title), ["Intro", "Couplet 1", "Refrain 1", "Couplet 2", "Refrain 2"])
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
        XCTAssertEqual(try countOf(Project.self), 2)
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
        let project = ProjectService.create(name: "Vide", type: .blank, in: context)
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
        let empty = ProjectService.create(name: "Vide", type: .blank, in: context)

        let sampleGaps = ProjectInsights.insights(for: sample).count
        let emptyGaps = ProjectInsights.insights(for: empty).count

        XCTAssertLessThan(sampleGaps, emptyGaps)
    }
}
