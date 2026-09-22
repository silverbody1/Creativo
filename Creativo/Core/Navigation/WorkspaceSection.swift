import Foundation

/// Sections of a project workspace, in sidebar order.
///
/// Sections that are not built yet still exist here and render a real empty
/// state, so that adding the feature later is a view swap and never a
/// navigation change.
enum WorkspaceSection: String, CaseIterable, Identifiable, Hashable, Sendable {
    case overview
    case writing
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
        case .overview, .scenes, .shots, .locations, .people, .equipment, .budget, .schedule:
            return true
        case .writing, .board, .documents:
            return false
        }
    }

    /// Visual grouping used by the workspace sidebar.
    static let creationGroup: [WorkspaceSection] = [.overview, .writing, .scenes, .shots, .board]
    static let productionGroup: [WorkspaceSection] = [.locations, .people, .equipment]
    static let organisationGroup: [WorkspaceSection] = [.budget, .schedule, .documents]
}
