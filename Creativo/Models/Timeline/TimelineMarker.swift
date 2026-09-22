import Foundation
import SwiftData

/// A point in time on a project's timeline.
///
/// Markers are deliberately not scenes: a drum entry, a drop or a lyric hit is
/// an instant worth remembering, not a unit of the breakdown. Keeping them
/// separate is what stops the scene list filling with objects that will never
/// carry a shot.
@Model
final class TimelineMarker {
    var id: UUID = UUID()
    /// Position in the track, in seconds from its start.
    var time: TimeInterval = 0
    var title: String = ""
    var type: TimelineMarkerType = TimelineMarkerType.standard
    var notes: String = ""
    var createdAt: Date = Date()
    var updatedAt: Date = Date()

    var project: Project?

    init(
        time: TimeInterval = 0,
        title: String = "",
        type: TimelineMarkerType = .standard,
        notes: String = "",
        createdAt: Date = .now
    ) {
        self.id = UUID()
        self.time = max(time, 0)
        self.title = title
        self.type = type
        self.notes = notes
        self.createdAt = createdAt
        self.updatedAt = createdAt
    }
}

extension TimelineMarker {
    var displayTitle: String {
        title.isBlank ? type.displayName : title.trimmed
    }

    /// Spoken description, so VoiceOver announces more than a coloured pin.
    var accessibilityDescription: String {
        "\(type.displayName), \(displayTitle), \(AppFormat.preciseTimecode(time))"
    }

    func touch(_ date: Date = .now) {
        updatedAt = date
        project?.touch(date)
    }
}

/// What a marker points at.
enum TimelineMarkerType: String, Codable, CaseIterable, Identifiable, Sendable {
    case standard
    case beat
    case lyric
    case camera
    case note

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .standard: return "Repère"
        case .beat: return "Impact"
        case .lyric: return "Parole"
        case .camera: return "Caméra"
        case .note: return "Note"
        }
    }

    var symbolName: String {
        switch self {
        case .standard: return "mappin"
        case .beat: return "waveform.path"
        case .lyric: return "quote.bubble"
        case .camera: return "camera"
        case .note: return "note.text"
        }
    }

    /// Short glyph drawn on the marker lane, so a marker is never identified by
    /// colour alone.
    var badge: String {
        switch self {
        case .standard: return "•"
        case .beat: return "♪"
        case .lyric: return "„"
        case .camera: return "◎"
        case .note: return "✎"
        }
    }
}
