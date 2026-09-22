import Foundation
import SwiftData

/// One line of a project budget.
///
/// Money is stored as `Decimal`, never `Double`: binary floating point cannot
/// represent amounts like 0.10 exactly and the rounding drift becomes visible
/// as soon as a few dozen lines are summed.
@Model
final class BudgetLine {
    var id: UUID = UUID()
    var category: BudgetCategory = BudgetCategory.miscellaneous
    var title: String = ""
    var quantity: Int = 1
    var unitPrice: Decimal = Decimal(0)
    var numberOfDays: Int = 1
    /// Fractional rate, e.g. `0.20` for 20 %. `nil` means "no tax on this line".
    var taxRate: Decimal?
    /// Amount actually paid, once known. Drives the "dépensé" figure.
    var actualAmount: Decimal?
    var status: BudgetLineStatus = BudgetLineStatus.estimated
    var notes: String = ""
    var createdAt: Date = Date()
    var updatedAt: Date = Date()

    var project: Project?

    init(
        category: BudgetCategory = .miscellaneous,
        title: String = "",
        quantity: Int = 1,
        unitPrice: Decimal = 0,
        numberOfDays: Int = 1,
        taxRate: Decimal? = nil,
        actualAmount: Decimal? = nil,
        status: BudgetLineStatus = .estimated,
        notes: String = "",
        createdAt: Date = .now
    ) {
        self.id = UUID()
        self.category = category
        self.title = title
        self.quantity = quantity
        self.unitPrice = unitPrice
        self.numberOfDays = numberOfDays
        self.taxRate = taxRate
        self.actualAmount = actualAmount
        self.status = status
        self.notes = notes
        self.createdAt = createdAt
        self.updatedAt = createdAt
    }
}

extension BudgetLine {
    /// Standard VAT rate proposed when the user turns tax on for a line.
    ///
    /// Built by division, not from a `0.20` literal: a float literal goes
    /// through `Double` and would not land on an exact decimal.
    static let defaultTaxRate: Decimal = Decimal(20) / Decimal(100)

    var displayTitle: String {
        title.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
            ? "Ligne sans intitulé"
            : title
    }

    /// `quantité × prix unitaire × nombre de jours`, before tax.
    var subtotal: Decimal {
        Decimal(quantity) * unitPrice * Decimal(numberOfDays)
    }

    var taxAmount: Decimal {
        guard let taxRate else { return 0 }
        return subtotal * taxRate
    }

    /// Forecast total for this line, tax included.
    var estimatedTotal: Decimal {
        subtotal + taxAmount
    }

    /// What this line contributes to the forecast. Cancelled lines contribute nothing.
    var forecastContribution: Decimal {
        status.countsInTotals ? estimatedTotal : 0
    }

    /// What this line contributes to the amount already spent.
    var spentContribution: Decimal {
        guard status.countsInTotals, let actualAmount else { return 0 }
        return actualAmount
    }

    /// Difference between what was paid and what was forecast, when both are known.
    var variance: Decimal? {
        guard let actualAmount else { return nil }
        return actualAmount - estimatedTotal
    }

    func touch(_ date: Date = .now) {
        updatedAt = date
        project?.touch(date)
    }
}
