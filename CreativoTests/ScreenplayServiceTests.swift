import XCTest
import SwiftData
@testable import Creativo

final class ScreenplayServiceTests: CreativoTestCase {
    private func makeScene() -> StoryScene {
        let project = ProjectService.create(name: "LISIÈRE", type: .film, context: context)
        return SceneService.create(in: project, title: "La clairière", context: context)
    }

    func testAppendingElementsKeepsThemOrdered() throws {
        let scene = makeScene()
        let first = ScreenplayService.append(.action, text: "Il entre.", to: scene, context: context)
        let second = ScreenplayService.append(.character, text: "NOÉ", to: scene, context: context)

        XCTAssertEqual(scene.screenplayElements.count, 2)
        XCTAssertEqual(first.orderIndex, 0)
        XCTAssertEqual(second.orderIndex, 1)
        XCTAssertEqual(scene.sortedScreenplayElements.map(\.text), ["Il entre.", "NOÉ"])
        XCTAssertTrue(scene.hasScreenplay)
    }

    func testInsertUsesTheNaturalSuccessorAndShiftsTheRest() throws {
        let scene = makeScene()
        let cue = ScreenplayService.append(.character, text: "NOÉ", to: scene, context: context)
        let last = ScreenplayService.append(.action, text: "Fin.", to: scene, context: context)

        let inserted = try XCTUnwrap(ScreenplayService.insert(after: cue, context: context))

        XCTAssertEqual(inserted.type, .dialogue)
        XCTAssertEqual(scene.sortedScreenplayElements.map(\.id), [cue.id, inserted.id, last.id])
        XCTAssertEqual(scene.sortedScreenplayElements.map(\.orderIndex), [0, 1, 2])
    }

    func testInsertHonoursAnExplicitType() throws {
        let scene = makeScene()
        let action = ScreenplayService.append(.action, to: scene, context: context)
        let inserted = try XCTUnwrap(ScreenplayService.insert(.transition, after: action, context: context))
        XCTAssertEqual(inserted.type, .transition)
    }

    func testDeletingAnElementReindexesItsSiblings() throws {
        let scene = makeScene()
        let a = ScreenplayService.append(.action, text: "A", to: scene, context: context)
        let b = ScreenplayService.append(.action, text: "B", to: scene, context: context)
        let c = ScreenplayService.append(.action, text: "C", to: scene, context: context)

        ScreenplayService.delete(b, context: context)

        XCTAssertEqual(scene.sortedScreenplayElements.map(\.text), ["A", "C"])
        XCTAssertEqual(a.orderIndex, 0)
        XCTAssertEqual(c.orderIndex, 1)
    }

    func testMovingAnElementRewritesEveryIndex() throws {
        let scene = makeScene()
        ScreenplayService.append(.action, text: "A", to: scene, context: context)
        ScreenplayService.append(.action, text: "B", to: scene, context: context)
        ScreenplayService.append(.action, text: "C", to: scene, context: context)

        ScreenplayService.move(fromOffsets: IndexSet(integer: 2), toOffset: 0, in: scene, context: context)

        XCTAssertEqual(scene.sortedScreenplayElements.map(\.text), ["C", "A", "B"])
        XCTAssertEqual(scene.sortedScreenplayElements.map(\.orderIndex), [0, 1, 2])
    }

    func testShiftingPastTheEdgeIsANoOp() throws {
        let scene = makeScene()
        let first = ScreenplayService.append(.action, text: "A", to: scene, context: context)
        ScreenplayService.append(.action, text: "B", to: scene, context: context)

        ScreenplayService.shift(first, by: -1, context: context)
        XCTAssertEqual(scene.sortedScreenplayElements.map(\.text), ["A", "B"])

        ScreenplayService.shift(first, by: 1, context: context)
        XCTAssertEqual(scene.sortedScreenplayElements.map(\.text), ["B", "A"])
    }

    func testChangingTypeUpdatesThePlainTextCopy() throws {
        let scene = makeScene()
        let element = ScreenplayService.append(.action, text: "noé", to: scene, context: context)

        ScreenplayService.setType(.character, on: element, context: context)

        XCTAssertEqual(element.type, .character)
        XCTAssertTrue(scene.content.contains("NOÉ"))
    }

    func testPlainTextCopyStaysInSyncWithTheElements() throws {
        let scene = makeScene()
        ScreenplayService.append(.action, text: "Il entre.", to: scene, context: context)
        XCTAssertTrue(scene.content.contains("Il entre."))

        let cue = ScreenplayService.append(.character, text: "NOÉ", to: scene, context: context)
        XCTAssertTrue(scene.content.contains("NOÉ"))

        ScreenplayService.delete(cue, context: context)
        XCTAssertFalse(scene.content.contains("NOÉ"))
    }

    func testTrimmingRemovesOnlyTheTrailingEmptyLines() throws {
        let scene = makeScene()
        ScreenplayService.append(.action, text: "Garde-moi.", to: scene, context: context)
        ScreenplayService.append(.action, text: "", to: scene, context: context)
        ScreenplayService.append(.action, text: "   ", to: scene, context: context)

        ScreenplayService.trimTrailingEmptyElements(in: scene, context: context)

        XCTAssertEqual(scene.screenplayElements.count, 1)
        XCTAssertEqual(scene.sortedScreenplayElements.first?.text, "Garde-moi.")
    }

    // MARK: Import of pre-existing text

    func testExistingSceneTextIsImportedOnce() throws {
        let scene = makeScene()
        scene.content = "NOÉ\nTu viens ?\nIl sort sans répondre."

        XCTAssertTrue(ScreenplayService.importPlainTextIfNeeded(into: scene, context: context))
        XCTAssertEqual(scene.screenplayElements.count, 3)
        XCTAssertEqual(scene.sortedScreenplayElements.map(\.type), [.character, .dialogue, .action])

        // Running again must not duplicate anything.
        XCTAssertFalse(ScreenplayService.importPlainTextIfNeeded(into: scene, context: context))
        XCTAssertEqual(scene.screenplayElements.count, 3)
    }

    func testImportDoesNothingOnAnEmptyScene() throws {
        let scene = makeScene()
        XCTAssertFalse(ScreenplayService.importPlainTextIfNeeded(into: scene, context: context))
        XCTAssertTrue(scene.screenplayElements.isEmpty)
    }

    func testPrepareImportsEverySceneOfTheProject() throws {
        let project = ProjectService.create(name: "LISIÈRE", type: .film, context: context)
        let first = SceneService.create(in: project, title: "Une", context: context)
        let second = SceneService.create(in: project, title: "Deux", context: context)
        first.content = "Il marche."
        second.content = "Elle attend."

        ScreenplayService.prepare(project, context: context)

        XCTAssertEqual(first.screenplayElements.count, 1)
        XCTAssertEqual(second.screenplayElements.count, 1)
    }

    // MARK: Page count through the project

    func testPageCountGrowsWithTheWriting() throws {
        let project = ProjectService.create(name: "LISIÈRE", type: .film, context: context)
        XCTAssertEqual(ScreenplayFormatter.pageCount(for: project.sortedScenes), 0)

        let scene = SceneService.create(in: project, title: "Une", context: context)
        for _ in 0..<40 {
            ScreenplayService.append(.action, text: String(repeating: "a", count: 61), to: scene, context: context)
        }

        XCTAssertGreaterThan(ScreenplayFormatter.pageCount(for: project.sortedScenes), 1)
        XCTAssertTrue(ScreenplayFormatter.pageCountText(for: project.sortedScenes).contains("page"))
    }

    func testDeletingASceneDeletesItsScreenplay() throws {
        let scene = makeScene()
        ScreenplayService.append(.action, text: "A", to: scene, context: context)
        ScreenplayService.append(.action, text: "B", to: scene, context: context)
        XCTAssertEqual(try countOf(ScreenplayElement.self), 2)

        SceneService.delete(scene, context: context)

        XCTAssertEqual(try countOf(ScreenplayElement.self), 0)
    }
}
