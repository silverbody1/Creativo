import Foundation
import SwiftData

/// Aggregated figures shown at the top of the budget screen.
struct BudgetSummary: Equatable, Sendable {
    /// Envelope the production is aiming for, when the user set one.
    var target: Decimal?
    /// Sum of every active line, tax included.
    var forecast: Decimal
    /// Sum of the amounts actually paid.
    var spent: Decimal

    /// What is left of the envelope once the money already paid is deducted.
    var remaining: Decimal? {
        guard let target else { return nil }
        return target - spent
    }

    /// How the forecast compares with the envelope. Negative means over budget.
    var targetMargin: Decimal? {
        guard let target else { return nil }
        return target - forecast
    }

    /// 0...1 ratio of the forecast against the envelope, for progress bars.
    var forecastRatio: Double? {
        guard let target, target > 0 else { return nil }
        return NSDecimalNumber(decimal: forecast / target).doubleValue
    }

    var spentRatio: Double? {
        guard let target, target > 0 else { return nil }
        return NSDecimalNumber(decimal: spent / target).doubleValue
    }

    var isOverTarget: Bool {
        guard let target else { return false }
        return forecast > target
    }

    static let empty = BudgetSummary(target: nil, forecast: 0, spent: 0)
}

/// One budget category with its lines and its own totals.
struct BudgetCategoryTotal: Identifiable, Equatable {
    let category: BudgetCategory
    let lines: [BudgetLine]
    let forecast: Decimal
    let spent: Decimal

    var id: String { category.rawValue }

    static func == (lhs: BudgetCategoryTotal, rhs: BudgetCategoryTotal) -> Bool {
        lhs.category == rhs.category
            && lhs.forecast == rhs.forecast
            && lhs.spent == rhs.spent
            && lhs.lines.map(\.id) == rhs.lines.map(\.id)
    }
}

/// Pure budget arithmetic. No SwiftData, no SwiftUI, fully unit-testable.
enum BudgetCalculator {
    static func summary(lines: [BudgetLine], target: Decimal?) -> BudgetSummary {
        var forecast: Decimal = 0
        var spent: Decimal = 0
        for line in lines {
            forecast += line.forecastContribution
            spent += line.spentContribution
        }
        return BudgetSummary(target: target, forecast: forecast, spent: spent)
    }

    /// Groups lines by category, in the canonical category order, skipping
    /// categories that hold no line.
    static func totalsByCategory(lines: [BudgetLine]) -> [BudgetCategoryTotal] {
        let grouped = Dictionary(grouping: lines, by: \.category)
        return BudgetCategory.allCases.compactMap { category in
            guard let categoryLines = grouped[category], !categoryLines.isEmpty else { return nil }
            let sorted = categoryLines.sorted { $0.createdAt < $1.createdAt }
            let forecast = sorted.reduce(Decimal(0)) { $0 + $1.forecastContribution }
            let spent = sorted.reduce(Decimal(0)) { $0 + $1.spentContribution }
            return BudgetCategoryTotal(category: category, lines: sorted, forecast: forecast, spent: spent)
        }
    }
}

extension Project {
    /// Recomputed on every read, so the screen is always in sync with the lines.
    var budgetSummary: BudgetSummary {
        BudgetCalculator.summary(lines: budgetLines, target: targetBudget)
    }

    var budgetTotalsByCategory: [BudgetCategoryTotal] {
        BudgetCalculator.totalsByCategory(lines: budgetLines)
    }
}

/// Creation and deletion of budget lines.
enum BudgetService {
    @discardableResult
    static func create(
        in project: Project,
        category: BudgetCategory = .miscellaneous,
        title: String = "",
        quantity: Int = 1,
        unitPrice: Decimal = 0,
        numberOfDays: Int = 1,
        context: ModelContext
    ) -> BudgetLine {
        let line = BudgetLine(
            category: category,
            title: title,
            quantity: max(quantity, 1),
            unitPrice: unitPrice,
            numberOfDays: max(numberOfDays, 1)
        )
        line.project = project
        context.insert(line)
        project.touch()
        PersistenceActions.save(context)
        return line
    }

    static func delete(_ line: BudgetLine, context: ModelContext) {
        let project = line.project
        context.delete(line)
        project?.touch()
        PersistenceActions.save(context)
    }

    static func setTarget(_ target: Decimal?, on project: Project, context: ModelContext) {
        project.targetBudget = (target ?? 0) > 0 ? target : nil
        project.touch()
        PersistenceActions.save(context)
    }

    static func commitEdits(to line: BudgetLine, context: ModelContext) {
        line.quantity = max(line.quantity, 1)
        line.numberOfDays = max(line.numberOfDays, 1)
        line.touch()
        PersistenceActions.save(context)
    }
}
