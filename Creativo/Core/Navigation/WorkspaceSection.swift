import Foundation

/// Sections of a project workspace, in sidebar order.
///
/// Sections that are not built yet still exist here and render a real empty
/// state, so that adding the feature later is a view swap and never a
/// navigation change.
enum WorkspaceSection: String, CaseIterable, Identifiable, Hashable, Sendable {
    case overview
    case writing
    case timeline
    case scenes
    case shots
    case board
    case locations
    case people
    case equipment
    case budget
    case schedule
    case documents

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .overview: return "Vue d'ensemble"
        case .writing: return "Écriture"
        case .timeline: return "Timeline"
        case .scenes: return "Scènes"
        case .shots: return "Plans"
        case .board: return "Board"
        case .locations: return "Lieux"
        case .people: return "Personnes"
        case .equipment: return "Matériel"
        case .budget: return "Budget"
        case .schedule: return "Planning"
        case .documents: return "Documents"
        }
    }

    var symbolName: String {
        switch self {
        case .overview: return "square.grid.2x2"
        case .writing: return "text.alignleft"
        case .timeline: return "waveform"
        case .scenes: return "list.bullet.rectangle"
        case .shots: return "camera.viewfinder"
        case .board: return "rectangle.3.group"
        case .locations: return "mappin.and.ellipse"
        case .people: return "person.2"
        case .equipment: return "shippingbox"
        case .budget: return "eurosign.circle"
        case .schedule: return "calendar"
        case .documents: return "doc.text"
        }
    }

    /// `true` for the sections fully implemented in phase 1.
    var isImplemented: Bool {
        switch self {
        case .overview, .writing, .timeline, .scenes, .shots, .locations, .people, .equipment, .budget, .schedule:
            return true
        case .board, .documents:
            return false
        }
    }

    /// Visual grouping used by the workspace sidebar.
    ///
    /// The creation group depends on the project: a timeline over an audio
    /// track means nothing for a screenplay, and an app that shows every
    /// feature to every project is an app nobody can read.
    static func creationGroup(for type: ProjectType) -> [WorkspaceSection] {
        var items: [WorkspaceSection] = [.overview, .writing]
        if type.hasAudioTimeline { items.append(.timeline) }
        items.append(contentsOf: [.scenes, .shots, .board])
        return items
    }

    static let productionGroup: [WorkspaceSection] = [.locations, .people, .equipment]
    static let organisationGroup: [WorkspaceSection] = [.budget, .schedule, .documents]

    /// Sections a project of this type is allowed to open.
    static func isAvailable(_ section: WorkspaceSection, for type: ProjectType) -> Bool {
        section != .timeline || type.hasAudioTimeline
    }
}

extension ProjectType {
    /// `true` for the project types whose preparation is built on a track.
    ///
    /// Only music videos today. The flag exists rather than a literal
    /// comparison so that enabling it for another type later is one line.
    var hasAudioTimeline: Bool {
        self == .musicVideo
    }
}
