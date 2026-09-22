import Foundation
import SwiftData

/// Sections of a music video.
///
/// A section is not a new kind of object: it is a `StoryScene` carrying a
/// `MusicVideoFacet`. Everything the rest of the app already knows how to do
/// with a scene — shots, location, shooting day, budget — therefore works on a
/// clip without a single special case.
enum MusicVideoService {
    // MARK: Preparation

    /// Gives every scene of a clip the facet the editor needs.
    ///
    /// Scenes written before this phase keep their title, their shots and their
    /// location; the facet is added beside them and its kind is inferred from
    /// the title, so a project called Intro / Couplet 1 / Refrain 1 opens
    /// already structured.
    static func prepare(_ project: Project, context: ModelContext) {
        var changed = false
        for scene in project.sortedScenes where scene.musicFacet == nil {
            let facet = MusicVideoFacet(kind: inferKind(from: scene.title) ?? .verse)
            facet.scene = scene
            context.insert(facet)
            changed = true
        }
        if changed {
            project.touch()
            PersistenceActions.save(context)
        }
    }

    /// Facet of a scene, created on the spot if it is missing.
    @discardableResult
    static func facet(for scene: StoryScene, context: ModelContext) -> MusicVideoFacet {
        if let existing = scene.musicFacet { return existing }
        let facet = MusicVideoFacet(kind: inferKind(from: scene.title) ?? .verse)
        facet.scene = scene
        context.insert(facet)
        scene.touch()
        PersistenceActions.save(context)
        return facet
    }

    // MARK: Sections

    @discardableResult
    static func createSection(
        in project: Project,
        kind: MusicSectionKind? = nil,
        context: ModelContext
    ) -> StoryScene {
        let resolvedKind = kind ?? suggestedNextKind(for: project)
        let scene = SceneService.create(
            in: project,
            title: sectionTitle(for: resolvedKind, in: project),
            context: context
        )
        let facet = MusicVideoFacet(kind: resolvedKind)
        facet.scene = scene
        context.insert(facet)

        // A clip picks up where the previous section ended.
        if let previousEnd = project.musicSections
            .compactMap({ $0.musicFacet?.endTime })
            .max() {
            facet.startTime = previousEnd
        }

        project.touch()
        PersistenceActions.save(context)
        return scene
    }

    static func delete(_ scene: StoryScene, context: ModelContext) {
        SceneService.delete(scene, context: context)
    }

    static func move(
        fromOffsets offsets: IndexSet,
        toOffset destination: Int,
        in project: Project,
        context: ModelContext
    ) {
        SceneService.move(fromOffsets: offsets, toOffset: destination, in: project, context: context)
    }

    static func shift(_ scene: StoryScene, by delta: Int, context: ModelContext) {
        SceneService.shift(scene, by: delta, context: context)
    }

    static func commitEdits(to facet: MusicVideoFacet, context: ModelContext) {
        // A section whose end precedes its start would produce a negative
        // duration everywhere downstream.
        if let start = facet.startTime, let end = facet.endTime, end < start {
            facet.endTime = start
        }
        facet.touch()
        PersistenceActions.save(context)
    }

    // MARK: Cast

    static func attach(_ person: Person, to facet: MusicVideoFacet, context: ModelContext) {
        guard !facet.people.contains(where: { $0.id == person.id }) else { return }
        facet.people.append(person)
        facet.touch()
        PersistenceActions.save(context)
    }

    static func detach(_ person: Person, from facet: MusicVideoFacet, context: ModelContext) {
        facet.people.removeAll { $0.id == person.id }
        facet.touch()
        PersistenceActions.save(context)
    }

    // MARK: Derived values

    /// Length of the clip from the section timecodes, when they are filled in.
    static func trackDuration(of project: Project) -> TimeInterval? {
        let ends = project.musicSections.compactMap { $0.musicFacet?.endTime }
        let starts = project.musicSections.compactMap { $0.musicFacet?.startTime }
        guard let last = ends.max(), let first = starts.min(), last > first else { return nil }
        return last - first
    }

    /// Sections that carry lyrics, used by the editor's summary line.
    static func lyricsLineCount(of project: Project) -> Int {
        project.musicSections.reduce(0) { $0 + ($1.musicFacet?.lyricsLineCount ?? 0) }
    }

    /// Kind proposed for the next section, following how songs are built.
    static func suggestedNextKind(for project: Project) -> MusicSectionKind {
        guard let last = project.musicSections.last?.musicFacet?.kind else { return .intro }
        switch last {
        case .intro: return .verse
        case .verse: return .chorus
        case .preChorus: return .chorus
        case .chorus: return .verse
        case .bridge: return .chorus
        case .outro: return .custom
        case .custom: return .verse
        }
    }

    /// `Couplet 2`, numbered from the sections of the same kind already there.
    static func sectionTitle(for kind: MusicSectionKind, in project: Project) -> String {
        guard kind != .custom else { return "" }
        let sameKind = project.musicSections.filter { $0.musicFacet?.kind == kind }.count
        return sameKind == 0 ? kind.displayName : "\(kind.displayName) \(sameKind + 1)"
    }

    /// Best-effort reading of a section kind from a scene title.
    static func inferKind(from title: String) -> MusicSectionKind? {
        let normalised = title
            .folding(options: [.diacriticInsensitive, .caseInsensitive], locale: .current)
        guard !normalised.isBlank else { return nil }

        let table: [(MusicSectionKind, [String])] = [
            (.preChorus, ["pre-refrain", "pre refrain", "prerefrain", "pre-chorus", "prechorus"]),
            (.chorus, ["refrain", "chorus", "hook"]),
            (.verse, ["couplet", "verse"]),
            (.bridge, ["pont", "bridge"]),
            (.intro, ["intro", "ouverture"]),
            (.outro, ["outro", "final", "fin"])
        ]
        for (kind, needles) in table where needles.contains(where: { normalised.contains($0) }) {
            return kind
        }
        return nil
    }
}
