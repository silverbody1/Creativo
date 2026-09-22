import Foundation
import SwiftData

/// The music-video side of a scene.
///
/// A clip has no narrative scenes, it has sections of a song — but they are the
/// same objects. Rather than a parallel list that would drift from the
/// breakdown, a section *is* a `StoryScene` carrying this facet. Its shots, its
/// location, its shooting day and its budget therefore come for free.
///
/// The facet holds only what is specific to a clip. Title, location, order,
/// shots and direction notes stay on the scene.
@Model
final class MusicVideoFacet {
    var id: UUID = UUID()
    var kind: MusicSectionKind = MusicSectionKind.verse
    /// Used when `kind` is `custom`.
    var customName: String = ""
    /// Optional position in the track, in seconds from its start.
    var startTime: TimeInterval?
    var endTime: TimeInterval?
    var lyrics: String = ""
    /// What the section should look like, in the director's words.
    var visualIdea: String = ""
    var performanceMode: MusicPerformanceMode = MusicPerformanceMode.mixed
    var wardrobe: String = ""
    var props: String = ""
    var createdAt: Date = Date()
    var updatedAt: Date = Date()

    var scene: StoryScene?

    /// Who appears in this section, borrowed from the global library.
    @Relationship(deleteRule: .nullify, inverse: \Person.musicSections)
    var people: [Person] = []

    init(
        kind: MusicSectionKind = .verse,
        customName: String = "",
        startTime: TimeInterval? = nil,
        endTime: TimeInterval? = nil,
        lyrics: String = "",
        visualIdea: String = "",
        performanceMode: MusicPerformanceMode = .mixed,
        wardrobe: String = "",
        props: String = "",
        createdAt: Date = .now
    ) {
        self.id = UUID()
        self.kind = kind
        self.customName = customName
        self.startTime = startTime
        self.endTime = endTime
        self.lyrics = lyrics
        self.visualIdea = visualIdea
        self.performanceMode = performanceMode
        self.wardrobe = wardrobe
        self.props = props
        self.createdAt = createdAt
        self.updatedAt = createdAt
    }
}

extension MusicVideoFacet {
    var displayName: String {
        kind == .custom && !customName.isBlank ? customName.trimmed : kind.displayName
    }

    /// Length of the section when both ends are known.
    var duration: TimeInterval? {
        guard let startTime, let endTime, endTime > startTime else { return nil }
        return endTime - startTime
    }

    /// `0:12 → 0:34`, or `nil` when no timecode was entered.
    var timecodeRange: String? {
        guard let startTime else { return nil }
        guard let endTime else { return AppFormat.timecode(startTime) }
        return "\(AppFormat.timecode(startTime)) → \(AppFormat.timecode(endTime))"
    }

    var lyricsLineCount: Int {
        lyrics.split(whereSeparator: \.isNewline).count
    }

    func touch(_ date: Date = .now) {
        updatedAt = date
        scene?.touch(date)
    }
}

/// Sections of a song, in the order they usually appear.
enum MusicSectionKind: String, Codable, CaseIterable, Identifiable, Sendable {
    case intro
    case verse
    case preChorus
    case chorus
    case bridge
    case outro
    case custom

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .intro: return "Intro"
        case .verse: return "Couplet"
        case .preChorus: return "Pré-refrain"
        case .chorus: return "Refrain"
        case .bridge: return "Pont"
        case .outro: return "Outro"
        case .custom: return "Section personnalisée"
        }
    }

    var symbolName: String {
        switch self {
        case .intro: return "play.circle"
        case .verse: return "text.alignleft"
        case .preChorus: return "arrow.up.right"
        case .chorus: return "star"
        case .bridge: return "arrow.triangle.branch"
        case .outro: return "stop.circle"
        case .custom: return "slider.horizontal.3"
        }
    }

    /// Colour weight: the chorus is the anchor of a clip and reads as such.
    var isAnchor: Bool { self == .chorus }
}

/// How a section is performed in front of the camera.
enum MusicPerformanceMode: String, Codable, CaseIterable, Identifiable, Sendable {
    case narrative
    case playback
    case performance
    case mixed

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .narrative: return "Narratif"
        case .playback: return "Playback"
        case .performance: return "Performance"
        case .mixed: return "Mixte"
        }
    }

    var shortDescription: String {
        switch self {
        case .narrative: return "L'histoire avance, sans chant à l'image."
        case .playback: return "L'artiste chante en playback face caméra."
        case .performance: return "Danse, groupe, énergie scénique."
        case .mixed: return "Alternance des registres dans la section."
        }
    }

    var symbolName: String {
        switch self {
        case .narrative: return "book"
        case .playback: return "mouth"
        case .performance: return "figure.dance"
        case .mixed: return "square.stack.3d.up"
        }
    }
}
