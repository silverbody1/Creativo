import XCTest
import SwiftData
@testable import Creativo

final class BudgetTests: CreativoTestCase {
    // MARK: Line arithmetic

    func testLineSubtotalIsQuantityTimesPriceTimesDays() {
        let line = BudgetLine(title: "Pack caméra", quantity: 2, unitPrice: 150, numberOfDays: 3)
        XCTAssertEqual(line.subtotal, 900)
        XCTAssertEqual(line.estimatedTotal, 900)
    }

    func testLineAppliesTaxWhenPresent() {
        let line = BudgetLine(title: "Studio", quantity: 1, unitPrice: 1_000, numberOfDays: 1, taxRate: BudgetLine.defaultTaxRate)
        XCTAssertEqual(line.subtotal, 1_000)
        XCTAssertEqual(line.taxAmount, 200)
        XCTAssertEqual(line.estimatedTotal, 1_200)
    }

    func testLineWithoutTaxHasNoTaxAmount() {
        let line = BudgetLine(title: "Repas", quantity: 10, unitPrice: 18, numberOfDays: 2)
        XCTAssertEqual(line.taxAmount, 0)
        XCTAssertEqual(line.estimatedTotal, 360)
    }

    func testDecimalArithmeticStaysExact() {
        // The reason money is a Decimal: 0.1 + 0.2 must be exactly 0.3.
        let line = BudgetLine(title: "Micro-achat", quantity: 3, unitPrice: Decimal(string: "0.10")!, numberOfDays: 1)
        XCTAssertEqual(line.subtotal, Decimal(string: "0.30"))
    }

    func testCancelledLineContributesNothing() {
        let line = BudgetLine(title: "Annulé", quantity: 1, unitPrice: 500, numberOfDays: 2, status: .cancelled)
        XCTAssertEqual(line.estimatedTotal, 1_000)
        XCTAssertEqual(line.forecastContribution, 0)
        XCTAssertEqual(line.spentContribution, 0)
    }

    func testSpentContributionUsesActualAmount() {
        let line = BudgetLine(title: "Studio", quantity: 1, unitPrice: 700, numberOfDays: 1, actualAmount: 650, status: .paid)
        XCTAssertEqual(line.spentContribution, 650)
        XCTAssertEqual(line.variance, -50)
    }

    func testVarianceIsNilWhenNothingWasPaid() {
        let line = BudgetLine(title: "Prévision", quantity: 1, unitPrice: 100, numberOfDays: 1)
        XCTAssertNil(line.variance)
    }

    // MARK: Aggregation

    func testSummarySumsForecastAndSpent() {
        let lines = [
            BudgetLine(title: "A", quantity: 1, unitPrice: 600, numberOfDays: 2),
            BudgetLine(title: "B", quantity: 2, unitPrice: 70, numberOfDays: 1, actualAmount: 150, status: .paid),
            BudgetLine(title: "C", quantity: 1, unitPrice: 999, numberOfDays: 1, status: .cancelled)
        ]

        let summary = BudgetCalculator.summary(lines: lines, target: 2_000)

        XCTAssertEqual(summary.forecast, 1_340)
        XCTAssertEqual(summary.spent, 150)
        XCTAssertEqual(summary.remaining, 1_850)
        XCTAssertEqual(summary.targetMargin, 660)
        XCTAssertFalse(summary.isOverTarget)
    }

    func testSummaryWithoutTargetHasNoRemaining() {
        let summary = BudgetCalculator.summary(lines: [BudgetLine(title: "A", quantity: 1, unitPrice: 100, numberOfDays: 1)], target: nil)
        XCTAssertNil(summary.remaining)
        XCTAssertNil(summary.targetMargin)
        XCTAssertNil(summary.forecastRatio)
        XCTAssertFalse(summary.isOverTarget)
    }

    func testSummaryDetectsOverspending() {
        let lines = [BudgetLine(title: "A", quantity: 1, unitPrice: 3_000, numberOfDays: 1)]
        let summary = BudgetCalculator.summary(lines: lines, target: 2_000)

        XCTAssertTrue(summary.isOverTarget)
        XCTAssertEqual(summary.targetMargin, -1_000)
    }

    func testTotalsByCategoryGroupAndSkipEmptyCategories() {
        let lines = [
            BudgetLine(category: .crew, title: "Réalisation", quantity: 1, unitPrice: 600, numberOfDays: 2),
            BudgetLine(category: .crew, title: "Image", quantity: 1, unitPrice: 450, numberOfDays: 2),
            BudgetLine(category: .catering, title: "Repas", quantity: 10, unitPrice: 18, numberOfDays: 1)
        ]

        let totals = BudgetCalculator.totalsByCategory(lines: lines)

        XCTAssertEqual(totals.count, 2)
        XCTAssertEqual(totals.first?.category, .crew)
        XCTAssertEqual(totals.first?.forecast, 2_100)
        XCTAssertEqual(totals.first?.lines.count, 2)
        XCTAssertEqual(totals.last?.category, .catering)
        XCTAssertEqual(totals.last?.forecast, 180)
    }

    // MARK: Through the project

    func testProjectBudgetSummaryReactsToLineChanges() throws {
        let project = ProjectService.create(name: "Budget", type: .blank, targetBudget: 1_000, in: context)
        XCTAssertEqual(project.budgetSummary.forecast, 0)

        let line = BudgetService.create(
            in: project,
            category: .equipment,
            title: "Caméra",
            quantity: 1,
            unitPrice: 200,
            numberOfDays: 2,
            in: context
        )
        XCTAssertEqual(project.budgetSummary.forecast, 400)

        line.numberOfDays = 3
        BudgetService.commitEdits(to: line, in: context)
        XCTAssertEqual(project.budgetSummary.forecast, 600)

        BudgetService.delete(line, in: context)
        XCTAssertEqual(project.budgetSummary.forecast, 0)
    }

    func testBudgetServiceClampsQuantityAndDaysToAtLeastOne() throws {
        let project = ProjectService.create(name: "Budget", type: .blank, in: context)
        let line = BudgetService.create(in: project, title: "Ligne", quantity: 0, unitPrice: 50, numberOfDays: 0, in: context)

        XCTAssertEqual(line.quantity, 1)
        XCTAssertEqual(line.numberOfDays, 1)

        line.quantity = -5
        line.numberOfDays = 0
        BudgetService.commitEdits(to: line, in: context)

        XCTAssertEqual(line.quantity, 1)
        XCTAssertEqual(line.numberOfDays, 1)
    }

    func testSetTargetTreatsZeroAsNoEnvelope() throws {
        let project = ProjectService.create(name: "Budget", type: .blank, in: context)

        BudgetService.setTarget(5_000, on: project, in: context)
        XCTAssertEqual(project.targetBudget, 5_000)

        BudgetService.setTarget(0, on: project, in: context)
        XCTAssertNil(project.targetBudget)
    }
}
