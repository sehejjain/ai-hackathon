import Foundation
import SwiftData

@Model
final class Budget: Identifiable, Hashable {
    #Index<Budget>([\.categoryRaw])
    enum BudgetError: Error {
        case invalidMonthlyLimit
        case invalidAlertThreshold
    }
    @Attribute(.unique) var id: UUID
    @Attribute(.unique) private var categoryRaw: String
    var monthlyLimit: Decimal
    var currentSpent: Decimal
    var alertThreshold: Double

    @Relationship(deleteRule: .cascade, inverse: \Transaction.budget) var transactions: [Transaction] = []

    var category: TransactionCategory {
        get {
            TransactionCategory(rawValue: categoryRaw) ?? .other
        }
        set {
            categoryRaw = newValue.rawValue
        }
    }

    enum Status {
        case safe
        case warning
        case danger
    }

    init(
        id: UUID = UUID(),
        category: TransactionCategory,
        monthlyLimit: Decimal,
        currentSpent: Decimal = 0,
        alertThreshold: Double = 0.8
    ) throws {
        guard monthlyLimit > 0 else {
            throw BudgetError.invalidMonthlyLimit
        }
        guard alertThreshold >= 0.0 && alertThreshold <= 1.0 else {
            throw BudgetError.invalidAlertThreshold
        }

        self.id = id
        self.categoryRaw = category.rawValue
        self.monthlyLimit = monthlyLimit
        self.currentSpent = max(0, currentSpent)
        self.alertThreshold = alertThreshold
    }


    var remainingAmount: Decimal {
        return max(0, monthlyLimit - currentSpent)
    }

    var utilizationPercentage: Double {
        guard monthlyLimit > 0 else { return 0 }
        return Double(truncating: NSDecimalNumber(decimal: currentSpent / monthlyLimit))
    }

    var isOverBudget: Bool {
        return currentSpent > monthlyLimit
    }

    var isNearLimit: Bool {
        return utilizationPercentage >= alertThreshold
    }

    var status: Status {
        if isOverBudget {
            return .danger
        } else if isNearLimit {
            return .warning
        } else {
            return .safe
        }
    }

    func updateSpentAmount(by amount: Decimal) {
        currentSpent = max(0, currentSpent + amount)
    }

    func resetMonthlySpent() {
        currentSpent = 0
    }

    func hash(into hasher: inout Hasher) {
        hasher.combine(id)
    }

    static func == (lhs: Budget, rhs: Budget) -> Bool {
        lhs.id == rhs.id
    }

    static func defaultBudgets() -> [Budget] {
        return [
            try! Budget(category: .utilities, monthlyLimit: 200),
            try! Budget(category: .groceries, monthlyLimit: 400),
            try! Budget(category: .transportation, monthlyLimit: 150),
            try! Budget(category: .dining, monthlyLimit: 300),
            try! Budget(category: .shopping, monthlyLimit: 250),
            try! Budget(category: .entertainment, monthlyLimit: 100)
        ]
    }

    static func sampleBudgets() -> [Budget] {
        return [
            try! Budget(category: .utilities, monthlyLimit: 200, currentSpent: 150),
            try! Budget(category: .groceries, monthlyLimit: 400, currentSpent: 320),
            try! Budget(category: .transportation, monthlyLimit: 150, currentSpent: 45),
            try! Budget(category: .dining, monthlyLimit: 300, currentSpent: 275),
            try! Budget(category: .shopping, monthlyLimit: 250, currentSpent: 180),
            try! Budget(category: .entertainment, monthlyLimit: 100, currentSpent: 95)
        ]
    }
}