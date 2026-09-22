import Foundation
import SwiftData

/// A piece of gear in the **global library**.
///
/// Projects never own equipment: they reference it through
/// `ProjectEquipmentAssignment`, which carries the per-project quantity, number
/// of days and rate override.
@Model
final class EquipmentItem {
    var id: UUID = UUID()
    var name: String = ""
    var category: EquipmentCategory = EquipmentCategory.other
    var brand: String = ""
    var model: String = ""
    /// `true` when the gear belongs to the user, `false` when it is rented.
    var owned: Bool = false
    /// Quantity available in the library, not the quantity used on a project.
    var quantity: Int = 1
    var defaultDailyRate: Decimal?
    var notes: String = ""
    var createdAt: Date = Date()
    var updatedAt: Date = Date()

    @Relationship(deleteRule: .cascade, inverse: \ProjectEquipmentAssignment.equipment)
    var assignments: [ProjectEquipmentAssignment] = []

    init(
        name: String = "",
        category: EquipmentCategory = .other,
        brand: String = "",
        model: String = "",
        owned: Bool = false,
        quantity: Int = 1,
        defaultDailyRate: Decimal? = nil,
        notes: String = "",
        createdAt: Date = .now
    ) {
        self.id = UUID()
        self.name = name
        self.category = category
        self.brand = brand
        self.model = model
        self.owned = owned
        self.quantity = quantity
        self.defaultDailyRate = defaultDailyRate
        self.notes = notes
        self.createdAt = createdAt
        self.updatedAt = createdAt
    }
}

extension EquipmentItem {
    var displayName: String {
        name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
            ? "Matériel sans nom"
            : name
    }

    /// `Sony · FX3`, empty when neither brand nor model is known.
    var makeAndModel: String {
        [brand, model]
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { !$0.isEmpty }
            .joined(separator: " · ")
    }

    var searchHaystack: String {
        [name, brand, model, category.displayName, notes].joined(separator: " ")
    }

    func touch(_ date: Date = .now) {
        updatedAt = date
    }
}
