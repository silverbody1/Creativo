import XCTest
import SwiftData
@testable import Creativo

/// Deletion is the riskiest operation in a relational model, so each rule has
/// its own test: owned children go, library entities stay.
final class DeletionTests: CreativoTestCase {
    func testDeletingAProjectRemovesItsOwnedChildren() throws {
        let project = ProjectService.create(name: "Clip", type: .musicVideo, context: context)
        let scene = SceneService.create(in: project, title: "Intro", context: context)
        ShotService.create(in: scene, title: "Apparition", context: context)
        BudgetService.create(in: project, title: "Caméra", quantity: 1, unitPrice: 200, numberOfDays: 1, context: context)
        ScheduleService.createDay(in: project, context: context)

        XCTAssertEqual(try countOf(StoryScene.self), 1)
        XCTAssertEqual(try countOf(Shot.self), 1)
        XCTAssertEqual(try countOf(BudgetLine.self), 1)
        XCTAssertEqual(try countOf(ShootDay.self), 1)

        ProjectService.delete(project, context: context)

        XCTAssertEqual(try countOf(Project.self), 0)
        XCTAssertEqual(try countOf(StoryScene.self), 0)
        XCTAssertEqual(try countOf(Shot.self), 0)
        XCTAssertEqual(try countOf(BudgetLine.self), 0)
        XCTAssertEqual(try countOf(ShootDay.self), 0)
    }

    func testDeletingAProjectKeepsLibraryEntities() throws {
        let project = ProjectService.create(name: "Clip", type: .musicVideo, context: context)
        let person = LibraryService.createPerson(firstName: "Camille", lastName: "Roux", context: context)
        let location = LibraryService.createLocation(name: "Studio Est", context: context)
        let gear = LibraryService.createEquipment(name: "FX3", category: .camera, context: context)

        LibraryService.assign(person, to: project, context: context)
        LibraryService.attach(location, to: project, context: context)
        LibraryService.assign(gear, to: project, context: context)

        ProjectService.delete(project, context: context)

        XCTAssertEqual(try countOf(Project.self), 0)
        XCTAssertEqual(try countOf(Person.self), 1)
        XCTAssertEqual(try countOf(ProductionLocation.self), 1)
        XCTAssertEqual(try countOf(EquipmentItem.self), 1)
        XCTAssertEqual(try countOf(ProjectPersonAssignment.self), 0)
        XCTAssertEqual(try countOf(ProjectEquipmentAssignment.self), 0)
    }

    func testDeletingASceneRemovesItsShotsAndReindexesTheRest() throws {
        let project = ProjectService.create(name: "Clip", type: .musicVideo, context: context)
        let first = SceneService.create(in: project, title: "A", context: context)
        let second = SceneService.create(in: project, title: "B", context: context)
        let third = SceneService.create(in: project, title: "C", context: context)
        ShotService.create(in: second, context: context)
        ShotService.create(in: second, context: context)

        XCTAssertEqual(try countOf(Shot.self), 2)

        SceneService.delete(second, context: context)

        XCTAssertEqual(try countOf(StoryScene.self), 2)
        XCTAssertEqual(try countOf(Shot.self), 0)
        XCTAssertEqual(project.sortedScenes.map(\.title), ["A", "C"])
        XCTAssertEqual(first.orderIndex, 0)
        XCTAssertEqual(third.orderIndex, 1)
    }

    func testDeletingAShotReindexesItsSiblings() throws {
        let project = ProjectService.create(name: "Clip", type: .musicVideo, context: context)
        let scene = SceneService.create(in: project, context: context)
        let a = ShotService.create(in: scene, title: "A", context: context)
        let b = ShotService.create(in: scene, title: "B", context: context)
        let c = ShotService.create(in: scene, title: "C", context: context)

        ShotService.delete(b, context: context)

        XCTAssertEqual(scene.sortedShots.map(\.title), ["A", "C"])
        XCTAssertEqual(a.orderIndex, 0)
        XCTAssertEqual(c.orderIndex, 1)
    }

    func testDeletingAPersonRemovesAssignmentsButKeepsProjects() throws {
        let clip = ProjectService.create(name: "Clip", type: .musicVideo, context: context)
        let film = ProjectService.create(name: "Film", type: .film, context: context)
        let person = LibraryService.createPerson(firstName: "Camille", lastName: "Roux", context: context)
        LibraryService.assign(person, to: clip, context: context)
        LibraryService.assign(person, to: film, context: context)

        LibraryService.deletePerson(person, context: context)

        XCTAssertEqual(try countOf(Person.self), 0)
        XCTAssertEqual(try countOf(ProjectPersonAssignment.self), 0)
        XCTAssertEqual(try countOf(Project.self), 2)
        XCTAssertTrue(clip.peopleAssignments.isEmpty)
        XCTAssertTrue(film.peopleAssignments.isEmpty)
    }

    func testDeletingEquipmentRemovesAssignmentsButKeepsProjects() throws {
        let project = ProjectService.create(name: "Clip", type: .musicVideo, context: context)
        let gear = LibraryService.createEquipment(name: "FX3", category: .camera, context: context)
        LibraryService.assign(gear, to: project, context: context)

        LibraryService.deleteEquipment(gear, context: context)

        XCTAssertEqual(try countOf(EquipmentItem.self), 0)
        XCTAssertEqual(try countOf(ProjectEquipmentAssignment.self), 0)
        XCTAssertEqual(try countOf(Project.self), 1)
        XCTAssertTrue(project.equipmentAssignments.isEmpty)
    }

    func testDetachingALocationClearsItOnTheScenesOfThatProjectOnly() throws {
        let clip = ProjectService.create(name: "Clip", type: .musicVideo, context: context)
        let film = ProjectService.create(name: "Film", type: .film, context: context)
        let studio = LibraryService.createLocation(name: "Studio Est", context: context)
        LibraryService.attach(studio, to: clip, context: context)
        LibraryService.attach(studio, to: film, context: context)

        let clipScene = SceneService.create(in: clip, title: "Intro", context: context)
        clipScene.location = studio
        let filmScene = SceneService.create(in: film, title: "Ouverture", context: context)
        filmScene.location = studio

        LibraryService.detach(studio, from: clip, context: context)

        XCTAssertTrue(clip.locations.isEmpty)
        XCTAssertNil(clipScene.location)
        XCTAssertEqual(film.locations.count, 1)
        XCTAssertEqual(filmScene.location?.id, studio.id)
        XCTAssertEqual(try countOf(ProductionLocation.self), 1)
    }

    func testUnassigningAPersonKeepsThemInTheLibrary() throws {
        let project = ProjectService.create(name: "Clip", type: .musicVideo, context: context)
        let person = LibraryService.createPerson(firstName: "Léa", lastName: "Moreau", context: context)
        let assignment = LibraryService.assign(person, to: project, context: context)

        LibraryService.unassign(assignment, context: context)

        XCTAssertEqual(try countOf(Person.self), 1)
        XCTAssertEqual(try countOf(ProjectPersonAssignment.self), 0)
        XCTAssertTrue(project.peopleAssignments.isEmpty)
    }

    /// The bug this guards against: SwiftData keeps a deleted object in its
    /// parent's to-many array until the context is saved, so anything that
    /// renumbers in the same turn used to renumber around a ghost.
    func testDeletionIsVisibleOnTheParentBeforeAnythingElseHappens() throws {
        let project = ProjectService.create(name: "Clip", type: .musicVideo, context: context)
        let scene = SceneService.create(in: project, title: "A", context: context)
        SceneService.create(in: project, title: "B", context: context)
        ShotService.create(in: scene, context: context)
        ScreenplayService.append(.action, text: "A", to: scene, context: context)
        let line = BudgetService.create(in: project, title: "Ligne", quantity: 1, unitPrice: 10, numberOfDays: 1, context: context)
        let day = ScheduleService.createDay(in: project, context: context)
        let block = YouTubeScriptService.append(.hook, to: project, context: context)

        SceneService.delete(scene, context: context)
        XCTAssertEqual(project.scenes.count, 1)
        XCTAssertFalse(project.scenes.contains { $0.id == scene.id })
        XCTAssertEqual(project.sortedScenes.map(\.orderIndex), [0])

        BudgetService.delete(line, context: context)
        XCTAssertTrue(project.budgetLines.isEmpty)

        ScheduleService.delete(day, context: context)
        XCTAssertTrue(project.shootDays.isEmpty)

        YouTubeScriptService.delete(block, context: context)
        XCTAssertTrue(project.youtubeBlocks.isEmpty)

        // The shot and the screenplay line went with their scene.
        XCTAssertEqual(try countOf(Shot.self), 0)
        XCTAssertEqual(try countOf(ScreenplayElement.self), 0)
    }

    func testDeletingTheLastScreenplayLineClearsTheSceneText() throws {
        let project = ProjectService.create(name: "Film", type: .film, context: context)
        let scene = SceneService.create(in: project, title: "Une", context: context)
        let element = ScreenplayService.append(.action, text: "Il entre.", to: scene, context: context)
        XCTAssertTrue(scene.content.contains("Il entre."))

        ScreenplayService.delete(element, context: context)

        XCTAssertFalse(scene.content.contains("Il entre."))
        XCTAssertTrue(scene.screenplayElements.isEmpty)
    }

    func testDeletingABudgetLineLeavesTheOthersIntact() throws {
        let project = ProjectService.create(name: "Clip", type: .musicVideo, context: context)
        let kept = BudgetService.create(in: project, title: "Gardée", quantity: 1, unitPrice: 100, numberOfDays: 1, context: context)
        let removed = BudgetService.create(in: project, title: "Retirée", quantity: 1, unitPrice: 300, numberOfDays: 1, context: context)

        BudgetService.delete(removed, context: context)

        XCTAssertEqual(project.budgetLines.map(\.id), [kept.id])
        XCTAssertEqual(project.budgetSummary.forecast, 100)
    }
}
