import XCTest
import SwiftData
@testable import Creativo

final class YouTubeScriptTests: CreativoTestCase {
    private func makeProject() -> Project {
        ProjectService.create(name: "Une vidéo", type: .youtube, context: context)
    }

    // MARK: Blocks

    func testAppendingBlocksKeepsThemOrdered() throws {
        let project = makeProject()
        let hook = YouTubeScriptService.append(.hook, title: "Accroche", to: project, context: context)
        let intro = YouTubeScriptService.append(.intro, title: "Intro", to: project, context: context)

        XCTAssertEqual(project.sortedYouTubeBlocks.map(\.id), [hook.id, intro.id])
        XCTAssertEqual(hook.orderIndex, 0)
        XCTAssertEqual(intro.orderIndex, 1)
        XCTAssertEqual(hook.project?.id, project.id)
    }

    func testInsertingShiftsTheFollowingBlocks() throws {
        let project = makeProject()
        let first = YouTubeScriptService.append(.hook, to: project, context: context)
        let last = YouTubeScriptService.append(.callToAction, to: project, context: context)

        let inserted = try XCTUnwrap(YouTubeScriptService.insert(.aRoll, after: first, context: context))

        XCTAssertEqual(project.sortedYouTubeBlocks.map(\.id), [first.id, inserted.id, last.id])
        XCTAssertEqual(project.sortedYouTubeBlocks.map(\.orderIndex), [0, 1, 2])
    }

    func testMovingABlockRewritesEveryIndex() throws {
        let project = makeProject()
        YouTubeScriptService.append(.hook, title: "A", to: project, context: context)
        YouTubeScriptService.append(.intro, title: "B", to: project, context: context)
        YouTubeScriptService.append(.aRoll, title: "C", to: project, context: context)

        YouTubeScriptService.move(fromOffsets: IndexSet(integer: 2), toOffset: 0, in: project, context: context)

        XCTAssertEqual(project.sortedYouTubeBlocks.map(\.title), ["C", "A", "B"])
        XCTAssertEqual(project.sortedYouTubeBlocks.map(\.orderIndex), [0, 1, 2])
    }

    func testDeletingABlockReindexesTheOthers() throws {
        let project = makeProject()
        let a = YouTubeScriptService.append(.hook, title: "A", to: project, context: context)
        let b = YouTubeScriptService.append(.intro, title: "B", to: project, context: context)
        let c = YouTubeScriptService.append(.aRoll, title: "C", to: project, context: context)

        YouTubeScriptService.delete(b, context: context)

        XCTAssertEqual(project.sortedYouTubeBlocks.map(\.title), ["A", "C"])
        XCTAssertEqual(a.orderIndex, 0)
        XCTAssertEqual(c.orderIndex, 1)
    }

    func testChangingKindAwayFromSectionClearsTheFold() throws {
        let project = makeProject()
        let section = YouTubeScriptService.append(.section, to: project, context: context)
        YouTubeScriptService.toggleCollapse(section, context: context)
        XCTAssertTrue(section.isCollapsed)

        YouTubeScriptService.setKind(.aRoll, on: section, context: context)

        XCTAssertEqual(section.kind, .aRoll)
        XCTAssertFalse(section.isCollapsed)
    }

    // MARK: Folding

    func testACollapsedSectionHidesTheBlocksUntilTheNextOne() throws {
        let project = makeProject()
        let sectionOne = YouTubeScriptService.append(.section, title: "Un", to: project, context: context)
        let hidden = YouTubeScriptService.append(.aRoll, title: "caché", to: project, context: context)
        let sectionTwo = YouTubeScriptService.append(.section, title: "Deux", to: project, context: context)
        let visible = YouTubeScriptService.append(.aRoll, title: "visible", to: project, context: context)

        YouTubeScriptService.toggleCollapse(sectionOne, context: context)

        let shown = YouTubeScriptService.visibleBlocks(in: project.sortedYouTubeBlocks)
        XCTAssertEqual(shown.map(\.id), [sectionOne.id, sectionTwo.id, visible.id])
        XCTAssertFalse(shown.contains { $0.id == hidden.id })
    }

    func testChildCountStopsAtTheNextSection() throws {
        let project = makeProject()
        let section = YouTubeScriptService.append(.section, to: project, context: context)
        YouTubeScriptService.append(.aRoll, to: project, context: context)
        YouTubeScriptService.append(.bRoll, to: project, context: context)
        YouTubeScriptService.append(.section, to: project, context: context)
        YouTubeScriptService.append(.aRoll, to: project, context: context)

        XCTAssertEqual(
            YouTubeScriptService.childCount(of: section, in: project.sortedYouTubeBlocks),
            2
        )
    }

    // MARK: Metrics

    func testOnlySpokenBlocksCountTowardsTheDuration() throws {
        let project = makeProject()
        project.wordsPerMinute = 150
        YouTubeScriptService.append(.aRoll, text: String(repeating: "mot ", count: 150), to: project, context: context)
        YouTubeScriptService.append(.bRoll, text: String(repeating: "mot ", count: 150), to: project, context: context)
        YouTubeScriptService.append(.editNote, text: String(repeating: "mot ", count: 150), to: project, context: context)

        let metrics = ScriptMetricsCalculator.metrics(for: project.youtubeBlocks, wordsPerMinute: 150)

        XCTAssertEqual(metrics.totalWords, 450)
        XCTAssertEqual(metrics.spokenWords, 150)
        XCTAssertEqual(metrics.estimatedDuration, 60, accuracy: 0.001)
    }

    func testSpeakingRateChangesTheEstimate() {
        let block = YouTubeBlock(kind: .voiceOver, text: String(repeating: "mot ", count: 300))
        let slow = ScriptMetricsCalculator.metrics(for: [block], wordsPerMinute: 100)
        let fast = ScriptMetricsCalculator.metrics(for: [block], wordsPerMinute: 200)

        XCTAssertEqual(slow.estimatedDuration, 180, accuracy: 0.001)
        XCTAssertEqual(fast.estimatedDuration, 90, accuracy: 0.001)
    }

    func testMetricsOfAnEmptyScriptAreZero() {
        let metrics = ScriptMetricsCalculator.metrics(for: [], wordsPerMinute: 150)
        XCTAssertEqual(metrics, .empty)
    }

    func testWordCountIgnoresExtraWhitespace() {
        XCTAssertEqual(ScriptMetricsCalculator.wordCount(in: "  un   deux \n trois "), 3)
        XCTAssertEqual(ScriptMetricsCalculator.wordCount(in: "   "), 0)
    }

    func testSectionsAreCounted() throws {
        let project = makeProject()
        YouTubeScriptService.append(.section, to: project, context: context)
        YouTubeScriptService.append(.aRoll, to: project, context: context)
        YouTubeScriptService.append(.section, to: project, context: context)

        let metrics = ScriptMetricsCalculator.metrics(for: project.youtubeBlocks, wordsPerMinute: 150)
        XCTAssertEqual(metrics.sectionCount, 2)
        XCTAssertEqual(metrics.blockCount, 3)
    }

    // MARK: Bridge to the breakdown

    func testPromotingABlockCreatesALinkedScene() throws {
        let project = makeProject()
        let block = YouTubeScriptService.append(.section, title: "Chapitre 1", text: "Ce qu'on raconte", to: project, context: context)

        let scene = try XCTUnwrap(YouTubeScriptService.promoteToScene(block, context: context))

        XCTAssertEqual(project.scenes.count, 1)
        XCTAssertEqual(scene.title, "Chapitre 1")
        XCTAssertEqual(scene.synopsis, "Ce qu'on raconte")
        XCTAssertEqual(block.scene?.id, scene.id)
    }

    func testPromotingTwiceReusesTheSameScene() throws {
        let project = makeProject()
        let block = YouTubeScriptService.append(.aRoll, title: "Face caméra", to: project, context: context)

        let first = try XCTUnwrap(YouTubeScriptService.promoteToScene(block, context: context))
        let second = try XCTUnwrap(YouTubeScriptService.promoteToScene(block, context: context))

        XCTAssertEqual(first.id, second.id)
        XCTAssertEqual(project.scenes.count, 1)
    }

    func testSomeKindsNeverBecomeScenes() throws {
        let project = makeProject()
        let source = YouTubeScriptService.append(.source, to: project, context: context)
        XCTAssertNil(YouTubeScriptService.promoteToScene(source, context: context))
        XCTAssertTrue(project.scenes.isEmpty)
    }

    func testDeletingAProjectDeletesItsScript() throws {
        let project = makeProject()
        YouTubeScriptService.append(.hook, to: project, context: context)
        YouTubeScriptService.append(.intro, to: project, context: context)
        XCTAssertEqual(try countOf(YouTubeBlock.self), 2)

        ProjectService.delete(project, context: context)

        XCTAssertEqual(try countOf(YouTubeBlock.self), 0)
    }

    // MARK: Starter outline

    func testStarterOutlineOnlyFillsAnEmptyScript() throws {
        let project = makeProject()
        YouTubeScriptService.starterOutline(for: project, context: context)
        let count = project.youtubeBlocks.count
        XCTAssertGreaterThan(count, 0)

        YouTubeScriptService.starterOutline(for: project, context: context)
        XCTAssertEqual(project.youtubeBlocks.count, count)
    }
}
