import XCTest
import SwiftData
@testable import Creativo

final class MusicVideoWritingTests: CreativoTestCase {
    private func makeProject() -> Project {
        ProjectService.create(name: "PARTENAIRE", type: .musicVideo, context: context)
    }

    // MARK: Sections are scenes

    func testCreatingASectionCreatesOneSceneWithAFacet() throws {
        let project = makeProject()
        let scene = MusicVideoService.createSection(in: project, kind: .intro, context: context)

        XCTAssertEqual(project.scenes.count, 1)
        XCTAssertEqual(project.musicSections.count, 1)
        XCTAssertEqual(scene.musicFacet?.kind, .intro)
        XCTAssertEqual(scene.musicFacet?.scene?.id, scene.id)
        XCTAssertEqual(try countOf(StoryScene.self), 1)
    }

    func testSectionsAreNumberedByKind() throws {
        let project = makeProject()
        let first = MusicVideoService.createSection(in: project, kind: .verse, context: context)
        let second = MusicVideoService.createSection(in: project, kind: .verse, context: context)

        XCTAssertEqual(first.title, "Couplet")
        XCTAssertEqual(second.title, "Couplet 2")
    }

    func testSuggestedKindFollowsHowSongsAreBuilt() throws {
        let project = makeProject()
        XCTAssertEqual(MusicVideoService.suggestedNextKind(for: project), .intro)

        MusicVideoService.createSection(in: project, kind: .intro, context: context)
        XCTAssertEqual(MusicVideoService.suggestedNextKind(for: project), .verse)

        MusicVideoService.createSection(in: project, kind: .verse, context: context)
        XCTAssertEqual(MusicVideoService.suggestedNextKind(for: project), .chorus)
    }

    func testANewSectionStartsWhereThePreviousOneEnded() throws {
        let project = makeProject()
        let first = MusicVideoService.createSection(in: project, kind: .intro, context: context)
        first.musicFacet?.endTime = 22

        let second = MusicVideoService.createSection(in: project, kind: .verse, context: context)

        XCTAssertEqual(second.musicFacet?.startTime, 22)
    }

    // MARK: Migration of scenes written before this phase

    func testPrepareGivesEveryExistingSceneAFacet() throws {
        let project = makeProject()
        let intro = SceneService.create(in: project, title: "Intro", context: context)
        let verse = SceneService.create(in: project, title: "Couplet 1", context: context)
        let chorus = SceneService.create(in: project, title: "Refrain 1", context: context)
        let bridge = SceneService.create(in: project, title: "Pont", context: context)
        XCTAssertTrue(project.musicSections.isEmpty)

        MusicVideoService.prepare(project, context: context)

        XCTAssertEqual(project.musicSections.count, 4)
        XCTAssertEqual(intro.musicFacet?.kind, .intro)
        XCTAssertEqual(verse.musicFacet?.kind, .verse)
        XCTAssertEqual(chorus.musicFacet?.kind, .chorus)
        XCTAssertEqual(bridge.musicFacet?.kind, .bridge)
    }

    func testPrepareKeepsEverythingTheSceneAlreadyHad() throws {
        let project = makeProject()
        let scene = SceneService.create(in: project, title: "Refrain 1", context: context)
        scene.synopsis = "Le rooftop s'ouvre."
        let shot = ShotService.create(in: scene, title: "Orbite", context: context)

        MusicVideoService.prepare(project, context: context)

        XCTAssertEqual(scene.synopsis, "Le rooftop s'ouvre.")
        XCTAssertEqual(scene.shots.map(\.id), [shot.id])
        XCTAssertEqual(scene.title, "Refrain 1")
    }

    func testPrepareIsIdempotent() throws {
        let project = makeProject()
        SceneService.create(in: project, title: "Intro", context: context)

        MusicVideoService.prepare(project, context: context)
        MusicVideoService.prepare(project, context: context)

        XCTAssertEqual(try countOf(MusicVideoFacet.self), 1)
    }

    func testKindInferenceIgnoresCaseAndAccents() {
        XCTAssertEqual(MusicVideoService.inferKind(from: "REFRAIN"), .chorus)
        XCTAssertEqual(MusicVideoService.inferKind(from: "pré-refrain"), .preChorus)
        XCTAssertEqual(MusicVideoService.inferKind(from: "Couplet 2"), .verse)
        XCTAssertEqual(MusicVideoService.inferKind(from: "Bridge"), .bridge)
        XCTAssertNil(MusicVideoService.inferKind(from: "Plan de coupe"))
        XCTAssertNil(MusicVideoService.inferKind(from: "   "))
    }

    // MARK: Editing

    func testAnEndBeforeTheStartIsCorrectedOnCommit() throws {
        let project = makeProject()
        let scene = MusicVideoService.createSection(in: project, kind: .chorus, context: context)
        let facet = try XCTUnwrap(scene.musicFacet)
        facet.startTime = 60
        facet.endTime = 30

        MusicVideoService.commitEdits(to: facet, context: context)

        XCTAssertEqual(facet.endTime, 60)
        XCTAssertNil(facet.duration)
    }

    func testDurationAndTimecodeRangeReadFromTheTimecodes() throws {
        let facet = MusicVideoFacet(kind: .chorus, startTime: 70, endTime: 108)
        XCTAssertEqual(facet.duration, 38)
        XCTAssertEqual(facet.timecodeRange, "01:10 → 01:48")

        let open = MusicVideoFacet(kind: .intro)
        XCTAssertNil(open.duration)
        XCTAssertNil(open.timecodeRange)
    }

    func testCustomSectionUsesItsOwnName() {
        let facet = MusicVideoFacet(kind: .custom, customName: "Interlude")
        XCTAssertEqual(facet.displayName, "Interlude")

        let unnamed = MusicVideoFacet(kind: .custom)
        XCTAssertEqual(unnamed.displayName, MusicSectionKind.custom.displayName)
    }

    func testLyricsLineCount() {
        let facet = MusicVideoFacet(kind: .verse, lyrics: "Une ligne\nDeux lignes\nTrois")
        XCTAssertEqual(facet.lyricsLineCount, 3)
    }

    func testTrackDurationSpansEveryTimedSection() throws {
        let project = makeProject()
        let first = MusicVideoService.createSection(in: project, kind: .intro, context: context)
        first.musicFacet?.startTime = 0
        first.musicFacet?.endTime = 22
        let last = MusicVideoService.createSection(in: project, kind: .outro, context: context)
        last.musicFacet?.startTime = 180
        last.musicFacet?.endTime = 206

        XCTAssertEqual(MusicVideoService.trackDuration(of: project), 206)
    }

    // MARK: Cast

    func testAttachingSomeoneToASectionIsIdempotent() throws {
        let project = makeProject()
        let scene = MusicVideoService.createSection(in: project, kind: .chorus, context: context)
        let facet = try XCTUnwrap(scene.musicFacet)
        let person = LibraryService.createPerson(firstName: "Naïma", lastName: "Belkacem", role: .artist, context: context)

        MusicVideoService.attach(person, to: facet, context: context)
        MusicVideoService.attach(person, to: facet, context: context)

        XCTAssertEqual(facet.people.count, 1)

        MusicVideoService.detach(person, from: facet, context: context)
        XCTAssertTrue(facet.people.isEmpty)
        XCTAssertEqual(try countOf(Person.self), 1)
    }

    // MARK: Ordering and deletion

    func testReorderingSectionsReordersTheScenes() throws {
        let project = makeProject()
        MusicVideoService.createSection(in: project, kind: .intro, context: context)
        MusicVideoService.createSection(in: project, kind: .verse, context: context)
        let chorus = MusicVideoService.createSection(in: project, kind: .chorus, context: context)

        MusicVideoService.move(fromOffsets: IndexSet(integer: 2), toOffset: 0, in: project, context: context)

        XCTAssertEqual(project.sortedScenes.first?.id, chorus.id)
        XCTAssertEqual(project.musicSections.first?.id, chorus.id)
        XCTAssertEqual(project.sortedScenes.map(\.orderIndex), [0, 1, 2])
    }

    func testDeletingASectionDeletesItsFacetAndItsShots() throws {
        let project = makeProject()
        let scene = MusicVideoService.createSection(in: project, kind: .chorus, context: context)
        ShotService.create(in: scene, context: context)
        XCTAssertEqual(try countOf(MusicVideoFacet.self), 1)
        XCTAssertEqual(try countOf(Shot.self), 1)

        MusicVideoService.delete(scene, context: context)

        XCTAssertEqual(try countOf(StoryScene.self), 0)
        XCTAssertEqual(try countOf(MusicVideoFacet.self), 0)
        XCTAssertEqual(try countOf(Shot.self), 0)
    }

    func testDeletingAPersonLeavesTheSectionsIntact() throws {
        let project = makeProject()
        let scene = MusicVideoService.createSection(in: project, kind: .chorus, context: context)
        let facet = try XCTUnwrap(scene.musicFacet)
        let person = LibraryService.createPerson(firstName: "Naïma", lastName: "Belkacem", context: context)
        MusicVideoService.attach(person, to: facet, context: context)

        LibraryService.deletePerson(person, context: context)

        XCTAssertEqual(try countOf(MusicVideoFacet.self), 1)
        XCTAssertTrue(facet.people.isEmpty)
    }
}
