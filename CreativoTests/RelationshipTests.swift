import XCTest
import SwiftData
@testable import Creativo

final class RelationshipTests: CreativoTestCase {
    func testScenesBelongToTheirProjectAndKeepOrder() throws {
        let project = ProjectService.create(name: "Clip", type: .musicVideo, context: context)

        let intro = SceneService.create(in: project, title: "Intro", context: context)
        let couplet = SceneService.create(in: project, title: "Couplet 1", context: context)
        let refrain = SceneService.create(in: project, title: "Refrain 1", context: context)

        XCTAssertEqual(project.scenes.count, 3)
        XCTAssertEqual(project.sortedScenes.map(\.title), ["Intro", "Couplet 1", "Refrain 1"])
        XCTAssertEqual(intro.orderIndex, 0)
        XCTAssertEqual(couplet.orderIndex, 1)
        XCTAssertEqual(refrain.orderIndex, 2)
        XCTAssertEqual(intro.project?.id, project.id)
    }

    func testSceneNumbersAreGeneratedSequentially() throws {
        let project = ProjectService.create(name: "Clip", type: .musicVideo, context: context)
        let first = SceneService.create(in: project, context: context)
        let second = SceneService.create(in: project, context: context)

        XCTAssertEqual(first.sceneNumber, "1")
        XCTAssertEqual(second.sceneNumber, "2")
    }

    func testShotsBelongToTheirSceneAndAreLettered() throws {
        let project = ProjectService.create(name: "Clip", type: .musicVideo, context: context)
        let scene = SceneService.create(in: project, title: "Intro", context: context)

        let a = ShotService.create(in: scene, title: "Apparition", context: context)
        let b = ShotService.create(in: scene, title: "Souffle", context: context)

        XCTAssertEqual(scene.shots.count, 2)
        XCTAssertEqual(a.shotNumber, "1A")
        XCTAssertEqual(b.shotNumber, "1B")
        XCTAssertEqual(a.scene?.id, scene.id)
        XCTAssertEqual(project.allShots.count, 2)
    }

    func testShotLetterRollsOverPastZ() {
        XCTAssertEqual(ShotService.letter(for: 0), "A")
        XCTAssertEqual(ShotService.letter(for: 25), "Z")
        XCTAssertEqual(ShotService.letter(for: 26), "AA")
        XCTAssertEqual(ShotService.letter(for: 27), "AB")
    }

    func testMovingASceneRewritesEveryOrderIndex() throws {
        let project = ProjectService.create(name: "Clip", type: .musicVideo, context: context)
        SceneService.create(in: project, title: "A", context: context)
        SceneService.create(in: project, title: "B", context: context)
        SceneService.create(in: project, title: "C", context: context)

        SceneService.move(fromOffsets: IndexSet(integer: 2), toOffset: 0, in: project, context: context)

        XCTAssertEqual(project.sortedScenes.map(\.title), ["C", "A", "B"])
        XCTAssertEqual(project.sortedScenes.map(\.orderIndex), [0, 1, 2])
    }

    func testShiftingASceneSwapsItWithItsNeighbour() throws {
        let project = ProjectService.create(name: "Clip", type: .musicVideo, context: context)
        SceneService.create(in: project, title: "A", context: context)
        let b = SceneService.create(in: project, title: "B", context: context)

        SceneService.shift(b, by: -1, context: context)
        XCTAssertEqual(project.sortedScenes.map(\.title), ["B", "A"])

        // Shifting past the edge is a no-op rather than an error.
        SceneService.shift(b, by: -1, context: context)
        XCTAssertEqual(project.sortedScenes.map(\.title), ["B", "A"])
    }

    func testRenumberingRewritesManualSceneNumbers() throws {
        let project = ProjectService.create(name: "Clip", type: .musicVideo, context: context)
        let a = SceneService.create(in: project, title: "A", context: context)
        let b = SceneService.create(in: project, title: "B", context: context)
        a.sceneNumber = "12A"
        b.sceneNumber = "48"

        SceneService.renumberSequentially(project, context: context)

        XCTAssertEqual(project.sortedScenes.map(\.sceneNumber), ["1", "2"])
    }

    func testShotProgressIgnoresCancelledShots() throws {
        let project = ProjectService.create(name: "Clip", type: .musicVideo, context: context)
        let scene = SceneService.create(in: project, context: context)

        let shot1 = ShotService.create(in: scene, context: context)
        let shot2 = ShotService.create(in: scene, context: context)
        let shot3 = ShotService.create(in: scene, context: context)

        ShotService.setStatus(.shot, on: shot1, context: context)
        ShotService.setStatus(.cancelled, on: shot2, context: context)
        ShotService.setStatus(.ready, on: shot3, context: context)

        XCTAssertEqual(project.shotProgress.completed, 1)
        XCTAssertEqual(project.shotProgress.total, 2)
    }

    func testAdvanceStatusCyclesThroughTheProductionStates() throws {
        let project = ProjectService.create(name: "Clip", type: .musicVideo, context: context)
        let scene = SceneService.create(in: project, context: context)
        let shot = ShotService.create(in: scene, context: context)

        XCTAssertEqual(shot.status, .planned)
        ShotService.advanceStatus(of: shot, context: context)
        XCTAssertEqual(shot.status, .ready)
        ShotService.advanceStatus(of: shot, context: context)
        XCTAssertEqual(shot.status, .shot)
        ShotService.advanceStatus(of: shot, context: context)
        XCTAssertEqual(shot.status, .planned)
    }

    func testOnePersonCanWorkOnSeveralProjects() throws {
        let clip = ProjectService.create(name: "Clip", type: .musicVideo, context: context)
        let film = ProjectService.create(name: "Film", type: .film, context: context)
        let person = LibraryService.createPerson(firstName: "Camille", lastName: "Roux", role: .directorOfPhotography, context: context)

        LibraryService.assign(person, to: clip, context: context)
        LibraryService.assign(person, to: film, context: context)

        XCTAssertEqual(person.assignments.count, 2)
        XCTAssertEqual(person.projectCount, 2)
        XCTAssertEqual(clip.people.map(\.id), [person.id])
        XCTAssertEqual(film.people.map(\.id), [person.id])
    }

    func testAssigningTheSamePersonTwiceIsIdempotent() throws {
        let project = ProjectService.create(name: "Clip", type: .musicVideo, context: context)
        let person = LibraryService.createPerson(firstName: "Léa", lastName: "Moreau", context: context)

        let first = LibraryService.assign(person, to: project, context: context)
        let second = LibraryService.assign(person, to: project, context: context)

        XCTAssertEqual(first.id, second.id)
        XCTAssertEqual(project.peopleAssignments.count, 1)
    }

    func testAssignmentFallsBackToTheLibraryRoleAndRate() throws {
        let project = ProjectService.create(name: "Clip", type: .musicVideo, context: context)
        let person = LibraryService.createPerson(firstName: "Yanis", lastName: "Bouchard", role: .gaffer, context: context)
        person.defaultRate = 280

        let assignment = LibraryService.assign(person, to: project, context: context)
        assignment.numberOfDays = 2

        XCTAssertEqual(assignment.effectiveRole, .gaffer)
        XCTAssertEqual(assignment.effectiveDailyRate, 280)
        XCTAssertEqual(assignment.estimatedCost, 560)

        assignment.roleOverride = .grip
        assignment.dailyRateOverride = 300
        XCTAssertEqual(assignment.effectiveRole, .grip)
        XCTAssertEqual(assignment.estimatedCost, 600)
    }

    func testLocationIsSharedBetweenProjectsAndScenes() throws {
        let clip = ProjectService.create(name: "Clip", type: .musicVideo, context: context)
        let film = ProjectService.create(name: "Film", type: .film, context: context)
        let studio = LibraryService.createLocation(name: "Studio Est", context: context)

        LibraryService.attach(studio, to: clip, context: context)
        LibraryService.attach(studio, to: film, context: context)

        let scene = SceneService.create(in: clip, title: "Intro", context: context)
        scene.location = studio

        XCTAssertEqual(clip.locations.count, 1)
        XCTAssertEqual(film.locations.count, 1)
        XCTAssertEqual(studio.projects.count, 2)
        XCTAssertEqual(scene.location?.id, studio.id)
    }

    func testEquipmentAssignmentComputesCostFromQuantityAndDays() throws {
        let project = ProjectService.create(name: "Clip", type: .musicVideo, context: context)
        let light = LibraryService.createEquipment(name: "600d", category: .lighting, context: context)
        light.defaultDailyRate = 70

        let assignment = LibraryService.assign(light, to: project, quantity: 2, context: context)
        assignment.numberOfDays = 3

        XCTAssertEqual(assignment.estimatedCost, 420)
    }

    func testShootDaysBelongToTheProjectAndSortByDate() throws {
        let project = ProjectService.create(name: "Clip", type: .musicVideo, context: context)
        let later = ScheduleService.createDay(in: project, date: Date(timeIntervalSince1970: 200_000), title: "Jour 2", context: context)
        let sooner = ScheduleService.createDay(in: project, date: Date(timeIntervalSince1970: 100_000), title: "Jour 1", context: context)

        XCTAssertEqual(project.shootDays.count, 2)
        XCTAssertEqual(project.sortedShootDays.map(\.id), [sooner.id, later.id])
        XCTAssertEqual(later.project?.id, project.id)
    }
}
