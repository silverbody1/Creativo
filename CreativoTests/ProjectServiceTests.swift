import XCTest
import SwiftData
@testable import Creativo

final class ProjectServiceTests: CreativoTestCase {
    func testCreateProjectPersistsIt() throws {
        let project = ProjectService.create(
            name: "PARTENAIRE",
            type: .musicVideo,
            targetBudget: 12_000,
            context: context
        )

        XCTAssertEqual(project.name, "PARTENAIRE")
        XCTAssertEqual(project.type, .musicVideo)
        XCTAssertEqual(project.status, .idea)
        XCTAssertEqual(project.targetBudget, 12_000)
        XCTAssertEqual(try countOf(Project.self), 1)
    }

    func testCreateProjectWithoutNameUsesTypeDefault() throws {
        let project = ProjectService.create(name: "   ", type: .commercial, context: context)
        XCTAssertEqual(project.name, ProjectService.defaultName(for: .commercial))
        XCTAssertFalse(project.displayName.isEmpty)
    }

    func testCreatedAtAndUpdatedAtStartEqual() throws {
        let project = ProjectService.create(name: "Test", type: .blank, context: context)
        XCTAssertEqual(project.createdAt, project.updatedAt)
    }

    func testTouchMovesUpdatedAtForward() throws {
        let project = ProjectService.create(name: "Test", type: .blank, context: context)
        let before = project.updatedAt
        project.touch(before.addingTimeInterval(60))
        XCTAssertGreaterThan(project.updatedAt, before)
    }

    func testToggleFavoriteFlipsTheFlag() throws {
        let project = ProjectService.create(name: "Test", type: .blank, context: context)
        XCTAssertFalse(project.isFavorite)

        ProjectService.toggleFavorite(project, context: context)
        XCTAssertTrue(project.isFavorite)

        ProjectService.toggleFavorite(project, context: context)
        XCTAssertFalse(project.isFavorite)
    }

    func testSetStatusUpdatesModificationDate() throws {
        let project = ProjectService.create(name: "Test", type: .blank, context: context)
        project.touch(Date(timeIntervalSince1970: 0))
        let before = project.updatedAt

        ProjectService.setStatus(.production, on: project, context: context)

        XCTAssertEqual(project.status, .production)
        XCTAssertGreaterThan(project.updatedAt, before)
    }

    func testFilterMatchesNameSynopsisAndType() throws {
        let clip = ProjectService.create(name: "PARTENAIRE", type: .musicVideo, context: context)
        clip.synopsis = "Un clip nocturne"
        let film = ProjectService.create(name: "LISIÈRE", type: .film, context: context)

        let projects = [clip, film]
        XCTAssertEqual(ProjectService.filter(projects, query: "parten").map(\.id), [clip.id])
        XCTAssertEqual(ProjectService.filter(projects, query: "nocturne").map(\.id), [clip.id])
        XCTAssertEqual(ProjectService.filter(projects, query: "lisiere").map(\.id), [film.id])
        XCTAssertEqual(ProjectService.filter(projects, query: "  ").count, 2)
    }

    func testSortedByRecencyPutsMostRecentFirst() throws {
        let old = ProjectService.create(name: "Ancien", type: .blank, context: context)
        let recent = ProjectService.create(name: "Récent", type: .blank, context: context)
        old.touch(Date(timeIntervalSince1970: 1_000))
        recent.touch(Date(timeIntervalSince1970: 2_000))

        XCTAssertEqual(ProjectService.sortedByRecency([old, recent]).map(\.id), [recent.id, old.id])
    }
}
