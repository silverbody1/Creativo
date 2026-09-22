import Foundation

/// Top level sections of the app shell.
enum SidebarDestination: String, CaseIterable, Identifiable, Hashable, Sendable {
    case home
    case allProjects
    case favorites
    case library
    case settings

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .home: return "Accueil"
        case .allProjects: return "Tous les projets"
        case .favorites: return "Favoris"
        case .library: return "Bibliothèque"
        case .settings: return "Réglages"
        }
    }

    var symbolName: String {
        switch self {
        case .home: return "house"
        case .allProjects: return "square.grid.2x2"
        case .favorites: return "star"
        case .library: return "books.vertical"
        case .settings: return "gearshape"
        }
    }

    /// The sidebar is split in two groups with a divider between them.
    static let primaryGroup: [SidebarDestination] = [.home, .allProjects, .favorites]
    static let secondaryGroup: [SidebarDestination] = [.library, .settings]
}

/// Sections of the global library.
enum LibrarySection: String, CaseIterable, Identifiable, Hashable, Sendable {
    case people
    case locations
    case equipment

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .people: return "Personnes"
        case .locations: return "Lieux"
        case .equipment: return "Matériel"
        }
    }

    var symbolName: String {
        switch self {
        case .people: return "person.2"
        case .locations: return "mappin.and.ellipse"
        case .equipment: return "camera"
        }
    }
}
