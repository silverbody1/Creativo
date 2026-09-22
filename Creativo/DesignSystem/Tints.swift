import SwiftUI

/// Presentation-only colour mapping for domain enums.
///
/// Lives in the design system, not in the models: the domain has no opinion on
/// colour. Every value is a system colour so both appearances are handled by
/// the platform.
extension ProjectType {
    var tint: Color {
        switch self {
        case .musicVideo: return .purple
        case .youtube: return .red
        case .film: return .indigo
        case .commercial: return .orange
        case .social: return .pink
        case .blank: return .gray
        }
    }
}

extension ProjectStatus {
    var tint: Color {
        switch self {
        case .idea: return .yellow
        case .writing: return .blue
        case .preProduction: return .teal
        case .production: return .orange
        case .postProduction: return .purple
        case .completed: return .green
        case .archived: return .gray
        }
    }
}

extension SceneStatus {
    var tint: Color {
        switch self {
        case .draft: return .gray
        case .written: return .blue
        case .revised: return .teal
        case .locked: return .indigo
        case .shot: return .green
        }
    }
}

extension ShotStatus {
    var tint: Color {
        switch self {
        case .planned: return .gray
        case .ready: return .blue
        case .shot: return .green
        case .cancelled: return .red
        }
    }
}

extension BudgetLineStatus {
    var tint: Color {
        switch self {
        case .estimated: return .gray
        case .quoted: return .blue
        case .committed: return .orange
        case .paid: return .green
        case .cancelled: return .red
        }
    }
}

extension BudgetCategory {
    var tint: Color {
        switch self {
        case .crew: return .blue
        case .cast: return .pink
        case .locations: return .teal
        case .equipment: return .indigo
        case .transport: return .brown
        case .catering: return .orange
        case .artDepartment: return .purple
        case .wardrobe: return .mint
        case .postProduction: return .cyan
        case .music: return .red
        case .insurance: return .gray
        case .permits: return .yellow
        case .miscellaneous: return .secondary
        }
    }
}

extension CrewDepartment {
    var tint: Color {
        switch self {
        case .direction: return .indigo
        case .production: return .blue
        case .camera: return .teal
        case .lighting: return .yellow
        case .sound: return .purple
        case .art: return .pink
        case .post: return .cyan
        case .cast: return .orange
        case .other: return .gray
        }
    }
}

extension EquipmentCategory {
    var tint: Color {
        switch self {
        case .camera: return .teal
        case .lens: return .indigo
        case .lighting: return .yellow
        case .grip: return .brown
        case .sound: return .purple
        case .power: return .green
        case .monitoring: return .blue
        case .drone: return .cyan
        case .storage: return .gray
        case .transport: return .orange
        case .other: return .secondary
        }
    }
}

extension ReferenceType {
    var tint: Color {
        switch self {
        case .image: return .teal
        case .video: return .indigo
        case .audio: return .purple
        case .link: return .blue
        case .document: return .orange
        case .note: return .yellow
        }
    }
}
