import XCTest
import SwiftData
@testable import Creativo

/// Deletion is the riskiest operation in a relational model, so each rule has
/// its own test: owned children go, library entities stay.
final class DeletionTests: CreativoTestCase {
    func testDeletingAProjectRemovesItsOwnedChildren() throws {
        let project = ProjectService.create(name: "Clip", type: .musicVideo, in: context)
        let scene = SceneService.create(in: project, title: "Intro", in: context)
        ShotService.create(in: scene, title: "Apparition", in: context)
        BudgetService.create(in: project, title: "Caméra", quantity: 1, unitPrice: 200, numberOfDays: 1, in: context)
        ScheduleService.createDay(in: project, in: context)

        XCTAssertEqual(try countOf(StoryScene.self), 1)
        XCTAssertEqual(try countOf(Shot.self), 1)
        XCTAssertEqual(try countOf(BudgetLine.self), 1)
        XCTAssertEqual(try countOf(ShootDay.self), 1)

        ProjectService.delete(project, in: context)

        XCTAssertEqual(try countOf(Project.self), 0)
        XCTAssertEqual(try countOf(StoryScene.self), 0)
        XCTAssertEqual(try countOf(Shot.self), 0)
        XCTAssertEqual(try countOf(BudgetLine.self), 0)
        XCTAssertEqual(try countOf(ShootDay.self), 0)
    }

    func testDeletingAProjectKeepsLibraryEntities() throws {
        let project = ProjectService.create(name: "Clip", type: .musicVideo, in: context)
        let person = LibraryService.createPerson(firstName: "Camille", lastName: "Roux", in: context)
        let location = LibraryService.createLocation(name: "Studio Est", in: context)
        let gear = LibraryService.createEquipment(name: "FX3", category: .camera, in: context)

        LibraryService.assign(person, to: project, in: context)
        LibraryService.attach(location, to: project, in: context)
        LibraryService.assign(gear, to: project, in: context)

        ProjectService.delete(project, in: context)

        XCTAssertEqual(try countOf(Project.self), 0)
        XCTAssertEqual(try countOf(Person.self), 1)
        XCTAssertEqual(try countOf(ProductionLocation.self), 1)
        XCTAssertEqual(try countOf(EquipmentItem.self), 1)
        XCTAssertEqual(try countOf(ProjectPersonAssignment.self), 0)
        XCTAssertEqual(try countOf(ProjectEquipmentAssignment.self), 0)
    }

    func testDeletingASceneRemovesItsShotsAndReindexesTheRest() throws {
        let project = ProjectService.create(name: "Clip", type: .musicVideo, in: context)
        let first = SceneService.create(in: project, title: "A", in: context)
        let second = SceneService.create(in: project, title: "B", in: context)
        let third = SceneService.create(in: project, title: "C", in: context)
        ShotService.create(in: second, in: context)
        ShotService.create(in: second, in: context)

        XCTAssertEqual(try countOf(Shot.self), 2)

        SceneService.delete(second, in: context)

        XCTAssertEqual(try countOf(StoryScene.self), 2)
        XCTAssertEqual(try countOf(Shot.self), 0)
        XCTAssertEqual(project.sortedScenes.map(\.title), ["A", "C"])
        XCTAssertEqual(first.orderIndex, 0)
        XCTAssertEqual(third.orderIndex, 1)
    }

    func testDeletingAShotReindexesItsSiblings() throws {
        let project = ProjectService.create(name: "Clip", type: .musicVideo, in: context)
        let scene = SceneService.create(in: project, in: context)
        let a = ShotService.create(in: scene, title: "A", in: context)
        let b = ShotService.create(in: scene, title: "B", in: context)
        let c = ShotService.create(in: scene, title: "C", in: context)

        ShotService.delete(b, in: context)

        XCTAssertEqual(scene.sortedShots.map(\.title), ["A", "C"])
        XCTAssertEqual(a.orderIndex, 0)
        XCTAssertEqual(c.orderIndex, 1)
    }

    func testDeletingAPersonRemovesAssignmentsButKeepsProjects() throws {
        let clip = ProjectService.create(name: "Clip", type: .musicVideo, in: context)
        let film = ProjectService.create(name: "Film", type: .film, in: context)
        let person = LibraryService.createPerson(firstName: "Camille", lastName: "Roux", in: context)
        LibraryService.assign(person, to: clip, in: context)
        LibraryService.assign(person, to: film, in: context)

        LibraryService.deletePerson(person, in: context)

        XCTAssertEqual(try countOf(Person.self), 0)
        XCTAssertEqual(try countOf(ProjectPersonAssignment.self), 0)
        XCTAssertEqual(try countOf(Project.self), 2)
        XCTAssertTrue(clip.peopleAssignments.isEmpty)
        XCTAssertTrue(film.peopleAssignments.isEmpty)
    }

    func testDeletingEquipmentRemovesAssignmentsButKeepsProjects() throws {
        let project = ProjectService.create(name: "Clip", type: .musicVideo, in: context)
        let gear = LibraryService.createEquipment(name: "FX3", category: .camera, in: context)
        LibraryService.assign(gear, to: project, in: context)

        LibraryService.deleteEquipment(gear, in: context)

        XCTAssertEqual(try countOf(EquipmentItem.self), 0)
        XCTAssertEqual(try countOf(ProjectEquipmentAssignment.self), 0)
        XCTAssertEqual(try countOf(Project.self), 1)
        XCTAssertTrue(project.equipmentAssignments.isEmpty)
    }

    func testDetachingALocationClearsItOnTheScenesOfThatProjectOnly() throws {
        let clip = ProjectService.create(name: "Clip", type: .musicVideo, in: context)
        let film = ProjectService.create(name: "Film", type: .film, in: context)
        let studio = LibraryService.createLocation(name: "Studio Est", in: context)
        LibraryService.attach(studio, to: clip, in: context)
        LibraryService.attach(studio, to: film, in: context)

        let clipScene = SceneService.create(in: clip, title: "Intro", in: context)
        clipScene.location = studio
        let filmScene = SceneService.create(in: film, title: "Ouverture", in: context)
        filmScene.location = studio

        LibraryService.detach(studio, from: clip, in: context)

        XCTAssertTrue(clip.locations.isEmpty)
        XCTAssertNil(clipScene.location)
        XCTAssertEqual(film.locations.count, 1)
        XCTAssertEqual(filmScene.location?.id, studio.id)
        XCTAssertEqual(try countOf(ProductionLocation.self), 1)
    }

    func testUnassigningAPersonKeepsThemInTheLibrary() throws {
        let project = ProjectService.create(name: "Clip", type: .musicVideo, in: context)
        let person = LibraryService.createPerson(firstName: "Léa", lastName: "Moreau", in: context)
        let assignment = LibraryService.assign(person, to: project, in: context)

        LibraryService.unassign(assignment, in: context)

        XCTAssertEqual(try countOf(Person.self), 1)
        XCTAssertEqual(try countOf(ProjectPersonAssignment.self), 0)
        XCTAssertTrue(project.peopleAssignments.isEmpty)
    }

    func testDeletingABudgetLineLeavesTheOthersIntact() throws {
        let project = ProjectService.create(name: "Clip", type: .musicVideo, in: context)
        let kept = BudgetService.create(in: project, title: "Gardée", quantity: 1, unitPrice: 100, numberOfDays: 1, in: context)
        let removed = BudgetService.create(in: project, title: "Retirée", quantity: 1, unitPrice: 300, numberOfDays: 1, in: context)

        BudgetService.delete(removed, in: context)

        XCTAssertEqual(project.budgetLines.map(\.id), [kept.id])
        XCTAssertEqual(project.budgetSummary.forecast, 100)
    }
}
