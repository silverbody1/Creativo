import Foundation

/// The kind of writing surface a project uses.
///
/// A project has exactly one active mode today, derived from its type and
/// overridable by the user. The value is stored rather than always computed so
/// that a later phase can let one project carry several modes at once without
/// a schema migration: the override already exists, only a set has to replace
/// the single value.
enum WritingMode: String, Codable, CaseIterable, Identifiable, Sendable {
    /// Screenplay format, for fiction, commercials and blank projects.
    case screenplay
    /// Structured outline with hook, sections, A-roll, B-roll and call to action.
    case youtube
    /// Song structure with lyrics, visual intentions and performance mode.
    case musicVideo

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .screenplay: return "Scénario"
        case .youtube: return "Script YouTube"
        case .musicVideo: return "Écriture de clip"
        }
    }

    var shortDescription: String {
        switch self {
        case .screenplay: return "Format scénario professionnel, scène par scène."
        case .youtube: return "Structure éditoriale : accroche, chapitres, A-roll, B-roll."
        case .musicVideo: return "Structure du morceau, paroles et intentions visuelles."
        }
    }

    var symbolName: String {
        switch self {
        case .screenplay: return "doc.text"
        case .youtube: return "play.rectangle.on.rectangle"
        case .musicVideo: return "music.note.list"
        }
    }
}

extension ProjectType {
    /// Writing surface proposed for this kind of project.
    var defaultWritingMode: WritingMode {
        switch self {
        case .film, .commercial, .blank: return .screenplay
        case .youtube, .social: return .youtube
        case .musicVideo: return .musicVideo
        }
    }
}
