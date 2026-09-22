import Foundation
import SwiftData

/// A human being in the **global library**.
///
/// A person never belongs to a single project: participation is expressed by
/// `ProjectPersonAssignment`, so the same director of photography can appear on
/// as many productions as needed while keeping one contact record.
@Model
final class Person {
    var id: UUID = UUID()
    var firstName: String = ""
    var lastName: String = ""
    /// Stage name or nickname. When filled it wins over first + last name,
    /// which is what artists and dancers usually expect on a call sheet.
    var nickname: String = ""
    var email: String = ""
    var phone: String = ""
    var notes: String = ""
    var defaultRate: Decimal?
    /// Default role, overridable per project by the assignment.
    var role: CrewRole = CrewRole.other
    var createdAt: Date = Date()
    var updatedAt: Date = Date()

    @Relationship(deleteRule: .cascade, inverse: \ProjectPersonAssignment.person)
    var assignments: [ProjectPersonAssignment] = []

    /// Shooting days this person is called on. Filled by the scheduling phase.
    var shootDays: [ShootDay] = []

    init(
        firstName: String = "",
        lastName: String = "",
        nickname: String = "",
        email: String = "",
        phone: String = "",
        notes: String = "",
        defaultRate: Decimal? = nil,
        role: CrewRole = .other,
        createdAt: Date = .now
    ) {
        self.id = UUID()
        self.firstName = firstName
        self.lastName = lastName
        self.nickname = nickname
        self.email = email
        self.phone = phone
        self.notes = notes
        self.defaultRate = defaultRate
        self.role = role
        self.createdAt = createdAt
        self.updatedAt = createdAt
    }
}

extension Person {
    /// Name shown everywhere in the interface.
    var displayName: String {
        let stage = nickname.trimmingCharacters(in: .whitespacesAndNewlines)
        if !stage.isEmpty { return stage }
        let full = "\(firstName) \(lastName)".trimmingCharacters(in: .whitespacesAndNewlines)
        return full.isEmpty ? "Sans nom" : full
    }

    var fullName: String {
        "\(firstName) \(lastName)".trimmingCharacters(in: .whitespacesAndNewlines)
    }

    /// Up to two letters for the avatar circle.
    var initials: String {
        let source = displayName
        let words = source.split(separator: " ").prefix(2)
        let letters = words.compactMap { $0.first.map(String.init) }
        return letters.isEmpty ? "?" : letters.joined().uppercased()
    }

    /// Number of distinct projects this person takes part in.
    var projectCount: Int {
        Set(assignments.compactMap { $0.project?.id }).count
    }

    /// Text used by the library search field.
    var searchHaystack: String {
        [displayName, fullName, email, phone, role.displayName, notes]
            .joined(separator: " ")
    }

    func touch(_ date: Date = .now) {
        updatedAt = date
    }
}
