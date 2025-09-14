import Foundation
import SwiftData

@Model
final class Budget: Identifiable, Hashable {
    enum BudgetError: Error {
        case invalidMonthlyLimit
        case invalidAlertThreshold
    }
    
    enum BudgetDataSource: String, CaseIterable, Codable {
        case local = "local"
        case backend = "backend"
        case hybrid = "hybrid"
    }
    
    @Attribute(.unique) var id: UUID
    @Attribute(.unique) var categoryRaw: String
    var monthlyLimit: Decimal
    var currentSpent: Decimal
    var alertThreshold: Double
    var dataSourceRaw: String?
    var backendSyncDate: Date?
    
    var dataSource: BudgetDataSource? {
        get {
            guard let raw = dataSourceRaw else { return nil }
            return BudgetDataSource(rawValue: raw)
        }
        set {
            dataSourceRaw = newValue?.rawValue
        }
    }

    @Relationship(deleteRule: .nullify, inverse: \Transaction.budget) var transactions: [Transaction] = []

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
    
    // MARK: - Backend Integration Properties
    
    var isFromBackend: Bool {
        return dataSource == .backend || dataSource == .hybrid
    }
    
    var isFromLocal: Bool {
        return dataSource == .local || dataSource == nil
    }

    func updateSpentAmount(by amount: Decimal) {
        currentSpent = max(0, currentSpent + amount)
    }

    func resetMonthlySpent() {
        currentSpent = 0
    }
    
    // MARK: - Backend Integration Methods
    
    convenience init(from backendBudget: BackendBudget) throws {
        try self.init(
            id: UUID(),
            category: TransactionCategory(rawValue: backendBudget.category) ?? .other,
            monthlyLimit: Decimal(backendBudget.monthlyLimit),
            currentSpent: Decimal(backendBudget.currentSpent),
            alertThreshold: backendBudget.utilizationPercentage >= 0.8 ? 0.8 : 0.9
        )
        self.dataSource = .backend
        self.backendSyncDate = Date()
    }
    
    func mergeWithBackendData(_ backendBudget: BackendBudget) {
        self.monthlyLimit = Decimal(backendBudget.monthlyLimit)
        self.currentSpent = Decimal(backendBudget.currentSpent)
        self.dataSource = .hybrid
        self.backendSyncDate = Date()
    }

    func hash(into hasher: inout Hasher) {
        hasher.combine(id)
    }

    static func == (lhs: Budget, rhs: Budget) -> Bool {
        lhs.id == rhs.id
    }

    static func defaultBudgets() -> [Budget] {
        let budgetConfigs: [(TransactionCategory, Decimal)] = [
            (.utilities, 200),
            (.groceries, 400),
            (.transportation, 150),
            (.dining, 300),
            (.shopping, 250),
            (.entertainment, 100)
        ]

        return budgetConfigs.compactMap { category, monthlyLimit in
            do {
                return try Budget(category: category, monthlyLimit: monthlyLimit)
            } catch {
                print("Failed to create default budget for \(category): \(error)")
                return nil
            }
        }
    }

    static func sampleBudgets() -> [Budget] {
        let budgetConfigs: [(TransactionCategory, Decimal, Decimal)] = [
            (.utilities, 200, 150),
            (.groceries, 400, 320),
            (.transportation, 150, 45),
            (.dining, 300, 275),
            (.shopping, 250, 180),
            (.entertainment, 100, 95)
        ]

        return budgetConfigs.compactMap { category, monthlyLimit, currentSpent in
            do {
                return try Budget(category: category, monthlyLimit: monthlyLimit, currentSpent: currentSpent)
            } catch {
                print("Failed to create sample budget for \(category): \(error)")
                return nil
            }
        }
    }
}
