import XCTest
import SwiftData
@testable import Creativo

final class WritingModeTests: CreativoTestCase {
    func testEachProjectTypeProposesTheRightSurface() {
        XCTAssertEqual(ProjectType.film.defaultWritingMode, .screenplay)
        XCTAssertEqual(ProjectType.commercial.defaultWritingMode, .screenplay)
        XCTAssertEqual(ProjectType.blank.defaultWritingMode, .screenplay)
        XCTAssertEqual(ProjectType.youtube.defaultWritingMode, .youtube)
        XCTAssertEqual(ProjectType.social.defaultWritingMode, .youtube)
        XCTAssertEqual(ProjectType.musicVideo.defaultWritingMode, .musicVideo)
    }

    func testAProjectFollowsItsTypeUntilItIsOverridden() throws {
        let project = ProjectService.create(name: "Clip", type: .musicVideo, context: context)
        XCTAssertEqual(project.writingMode, .musicVideo)
        XCTAssertNil(project.writingModeOverride)

        project.writingModeOverride = .screenplay
        XCTAssertEqual(project.writingMode, .screenplay)

        project.writingModeOverride = nil
        XCTAssertEqual(project.writingMode, .musicVideo)
    }

    func testChangingModeDestroysNothing() throws {
        let project = ProjectService.create(name: "Hybride", type: .musicVideo, context: context)

        let section = MusicVideoService.createSection(in: project, kind: .chorus, context: context)
        ScreenplayService.append(.action, text: "Elle entre.", to: section, context: context)
        YouTubeScriptService.append(.hook, title: "Accroche", to: project, context: context)

        project.writingModeOverride = .screenplay
        XCTAssertEqual(project.musicSections.count, 1)
        XCTAssertEqual(project.youtubeBlocks.count, 1)

        project.writingModeOverride = .youtube
        XCTAssertEqual(section.screenplayElements.count, 1)
        XCTAssertEqual(project.musicSections.count, 1)
    }

    func testWrittenMaterialIsDetectedForEverySurface() throws {
        let screenplay = ProjectService.create(name: "Film", type: .film, context: context)
        XCTAssertFalse(screenplay.hasWrittenMaterial)
        let scene = SceneService.create(in: screenplay, context: context)
        XCTAssertFalse(screenplay.hasWrittenMaterial)
        ScreenplayService.append(.action, text: "Il entre.", to: scene, context: context)
        XCTAssertTrue(screenplay.hasWrittenMaterial)

        let video = ProjectService.create(name: "Vidéo", type: .youtube, context: context)
        XCTAssertFalse(video.hasWrittenMaterial)
        YouTubeScriptService.append(.hook, to: video, context: context)
        XCTAssertTrue(video.hasWrittenMaterial)

        let clip = ProjectService.create(name: "Clip", type: .musicVideo, context: context)
        XCTAssertFalse(clip.hasWrittenMaterial)
        MusicVideoService.createSection(in: clip, kind: .intro, context: context)
        XCTAssertTrue(clip.hasWrittenMaterial)
    }

    func testTheWritingSectionIsNowImplemented() {
        XCTAssertTrue(WorkspaceSection.writing.isImplemented)
        XCTAssertFalse(WorkspaceSection.board.isImplemented)
        XCTAssertFalse(WorkspaceSection.documents.isImplemented)
    }

    func testSampleDataCoversTheThreeWritingSurfaces() throws {
        SampleData.populate(context)
        let projects = try fetchAll(Project.self)

        let clip = try XCTUnwrap(projects.first { $0.type == .musicVideo })
        XCTAssertEqual(clip.writingMode, .musicVideo)
        XCTAssertFalse(clip.musicSections.isEmpty)
        XCTAssertTrue(clip.musicSections.contains { !($0.musicFacet?.lyrics.isEmpty ?? true) })

        let film = try XCTUnwrap(projects.first { $0.type == .film })
        XCTAssertEqual(film.writingMode, .screenplay)
        XCTAssertTrue(film.sortedScenes.contains { $0.hasScreenplay })
        XCTAssertGreaterThan(ScreenplayFormatter.pageCount(for: film.sortedScenes), 0)

        let video = try XCTUnwrap(projects.first { $0.type == .youtube })
        XCTAssertEqual(video.writingMode, .youtube)
        XCTAssertFalse(video.youtubeBlocks.isEmpty)
        let metrics = ScriptMetricsCalculator.metrics(for: video.youtubeBlocks, wordsPerMinute: video.wordsPerMinute)
        XCTAssertGreaterThan(metrics.estimatedDuration, 0)
    }
}
