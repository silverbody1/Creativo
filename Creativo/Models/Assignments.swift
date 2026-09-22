import Foundation
import SwiftData

/// Join model between a `Project` and a `Person`.
///
/// This is what lets one person work on several productions while keeping a
/// single library record, and it is where anything project-specific lives:
/// the role held on *this* project, the negotiated rate, the number of days.
@Model
final class ProjectPersonAssignment {
    var id: UUID = UUID()
    /// Role for this project only. `nil` falls back to `Person.role`.
    var roleOverride: CrewRole?
    /// Rate for this project only. `nil` falls back to `Person.defaultRate`.
    var dailyRateOverride: Decimal?
    var numberOfDays: Int = 1
    var notes: String = ""
    var createdAt: Date = Date()

    var project: Project?
    var person: Person?

    init(
        project: Project? = nil,
        person: Person? = nil,
        roleOverride: CrewRole? = nil,
        dailyRateOverride: Decimal? = nil,
        numberOfDays: Int = 1,
        notes: String = "",
        createdAt: Date = .now
    ) {
        self.id = UUID()
        self.project = project
        self.person = person
        self.roleOverride = roleOverride
        self.dailyRateOverride = dailyRateOverride
        self.numberOfDays = numberOfDays
        self.notes = notes
        self.createdAt = createdAt
    }
}

extension ProjectPersonAssignment {
    var effectiveRole: CrewRole {
        roleOverride ?? person?.role ?? .other
    }

    var effectiveDailyRate: Decimal? {
        dailyRateOverride ?? person?.defaultRate
    }

    /// Forecast cost of this person on this project.
    var estimatedCost: Decimal? {
        guard let rate = effectiveDailyRate else { return nil }
        return rate * Decimal(numberOfDays)
    }

    var personDisplayName: String {
        person?.displayName ?? "Personne supprimée"
    }
}

/// Join model between a `Project` and an `EquipmentItem`.
@Model
final class ProjectEquipmentAssignment {
    var id: UUID = UUID()
    /// How many units this project needs, independent of library stock.
    var quantity: Int = 1
    var numberOfDays: Int = 1
    /// Rate for this project only. `nil` falls back to `EquipmentItem.defaultDailyRate`.
    var dailyRateOverride: Decimal?
    var notes: String = ""
    var createdAt: Date = Date()

    var project: Project?
    var equipment: EquipmentItem?

    init(
        project: Project? = nil,
        equipment: EquipmentItem? = nil,
        quantity: Int = 1,
        numberOfDays: Int = 1,
        dailyRateOverride: Decimal? = nil,
        notes: String = "",
        createdAt: Date = .now
    ) {
        self.id = UUID()
        self.project = project
        self.equipment = equipment
        self.quantity = quantity
        self.numberOfDays = numberOfDays
        self.dailyRateOverride = dailyRateOverride
        self.notes = notes
        self.createdAt = createdAt
    }
}

extension ProjectEquipmentAssignment {
    var effectiveDailyRate: Decimal? {
        dailyRateOverride ?? equipment?.defaultDailyRate
    }

    /// Forecast cost of this gear on this project. Owned gear with no rate costs nothing.
    var estimatedCost: Decimal? {
        guard let rate = effectiveDailyRate else { return nil }
        return rate * Decimal(quantity) * Decimal(numberOfDays)
    }

    var equipmentDisplayName: String {
        equipment?.displayName ?? "Matériel supprimé"
    }
}
