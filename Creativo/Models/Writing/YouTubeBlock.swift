import Foundation
import SwiftData

/// One block of a YouTube script, owned by the project.
///
/// A video script is an outline, not a scene breakdown, so blocks belong to the
/// project rather than to a scene. A block can still be promoted into a real
/// `StoryScene` when it deserves a shot list, a location and a shooting day:
/// that link is what keeps the writing connected to the rest of the app.
@Model
final class YouTubeBlock {
    var id: UUID = UUID()
    var kind: YouTubeBlockKind = YouTubeBlockKind.section
    var title: String = ""
    var text: String = ""
    var orderIndex: Int = 0
    /// Only meaningful on a `section`: folds every block up to the next section.
    var isCollapsed: Bool = false
    /// Reference link, used by `source` blocks.
    var urlString: String = ""
    var createdAt: Date = Date()
    var updatedAt: Date = Date()

    var project: Project?

    /// Set when the block has been promoted to a real scene.
    var scene: StoryScene?

    init(
        kind: YouTubeBlockKind = .section,
        title: String = "",
        text: String = "",
        orderIndex: Int = 0,
        urlString: String = "",
        createdAt: Date = .now
    ) {
        self.id = UUID()
        self.kind = kind
        self.title = title
        self.text = text
        self.orderIndex = orderIndex
        self.urlString = urlString
        self.createdAt = createdAt
        self.updatedAt = createdAt
    }
}

extension YouTubeBlock {
    var displayTitle: String {
        title.isBlank ? kind.displayName : title
    }

    var url: URL? {
        guard !urlString.isBlank else { return nil }
        return URL(string: urlString.trimmed)
    }

    /// Words that will actually be spoken aloud, used for the duration estimate.
    var spokenWordCount: Int {
        guard kind.isSpoken else { return 0 }
        return text.split { $0.isWhitespace || $0.isNewline }.count
    }

    func touch(_ date: Date = .now) {
        updatedAt = date
        project?.touch(date)
    }
}

/// The kinds of block a video script is made of.
enum YouTubeBlockKind: String, Codable, CaseIterable, Identifiable, Sendable {
    case hook
    case intro
    case section
    case aRoll
    case bRoll
    case voiceOver
    case callToAction
    case editNote
    case source

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .hook: return "Accroche"
        case .intro: return "Intro"
        case .section: return "Chapitre"
        case .aRoll: return "A-Roll"
        case .bRoll: return "B-Roll"
        case .voiceOver: return "Voix off"
        case .callToAction: return "Appel à l'action"
        case .editNote: return "Note de montage"
        case .source: return "Source"
        }
    }

    var symbolName: String {
        switch self {
        case .hook: return "bolt"
        case .intro: return "hand.wave"
        case .section: return "list.bullet.indent"
        case .aRoll: return "person.fill.viewfinder"
        case .bRoll: return "film"
        case .voiceOver: return "mic"
        case .callToAction: return "hand.tap"
        case .editNote: return "scissors"
        case .source: return "link"
        }
    }

    /// `true` when the block's text is read aloud on camera or in voice-over.
    /// B-roll descriptions, edit notes and sources are not.
    var isSpoken: Bool {
        switch self {
        case .hook, .intro, .aRoll, .voiceOver, .callToAction: return true
        case .section, .bRoll, .editNote, .source: return false
        }
    }

    /// Sections act as headers: they group the blocks that follow them.
    var isHeader: Bool { self == .section }

    /// Blocks worth turning into a real scene with its own shots.
    var canBecomeScene: Bool {
        switch self {
        case .hook, .intro, .section, .aRoll, .bRoll, .callToAction: return true
        case .voiceOver, .editNote, .source: return false
        }
    }

    /// Kinds offered first in the "add block" menu, in editing order.
    static let commonOrder: [YouTubeBlockKind] = [
        .hook, .intro, .section, .aRoll, .bRoll, .voiceOver, .callToAction, .editNote, .source
    ]
}
