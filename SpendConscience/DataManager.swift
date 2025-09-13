import Foundation
import SwiftData
import SwiftUI

@MainActor
class DataManager: ObservableObject {
    @Published var transactions: [Transaction] = []
    @Published var budgets: [Budget] = []
    @Published var isLoading = false
    @Published var error: DataError?

    private let modelContext: ModelContext

    enum DataError: Error, LocalizedError {
        case transactionSaveFailed
        case transactionLoadFailed
        case budgetSaveFailed
        case budgetLoadFailed
        case invalidData
        case contextUnavailable

        var errorDescription: String? {
            switch self {
            case .transactionSaveFailed:
                return "Failed to save transaction"
            case .transactionLoadFailed:
                return "Failed to load transactions"
            case .budgetSaveFailed:
                return "Failed to save budget"
            case .budgetLoadFailed:
                return "Failed to load budgets"
            case .invalidData:
                return "Invalid data format"
            case .contextUnavailable:
                return "Database context unavailable"
            }
        }
    }

    private var loadTask: Task<Void, Never>?

    init(modelContext: ModelContext) {
        self.modelContext = modelContext
        loadTask = Task { [weak self] in
            await self?.loadAllData()
        }
    }

    deinit {
        loadTask?.cancel()
    }

    // MARK: - Data Loading

    func loadAllData() async {
        isLoading = true
        error = nil

        await loadTransactions()
        await loadBudgets()
        await updateBudgetSpending()

        isLoading = false
    }

    private func loadTransactions() async {
        do {
            let descriptor = FetchDescriptor<Transaction>(
                sortBy: [SortDescriptor(\.date, order: .reverse)]
            )
            let loadedTransactions = try modelContext.fetch(descriptor)

            await MainActor.run {
                self.transactions = loadedTransactions
            }
        } catch {
            await MainActor.run {
                self.error = .transactionLoadFailed
            }
        }
    }

    private func loadBudgets() async {
        do {
            let descriptor = FetchDescriptor<Budget>()
            let loadedBudgets = try modelContext.fetch(descriptor)

            await MainActor.run {
                self.budgets = loadedBudgets
            }
        } catch {
            await MainActor.run {
                self.error = .budgetLoadFailed
            }
        }
    }

    // MARK: - Transaction Operations

    func saveTransaction(_ transaction: Transaction) async -> Bool {
        do {
            modelContext.insert(transaction)
            try modelContext.save()

            await MainActor.run {
                // Find the correct insertion index to maintain descending date order
                let insertionIndex = self.transactions.firstIndex { existingTransaction in
                    existingTransaction.date < transaction.date
                } ?? self.transactions.count

                self.transactions.insert(transaction, at: insertionIndex)
            }
            await updateBudgetForTransaction(transaction)
            return true
        } catch {
            await MainActor.run {
                self.error = .transactionSaveFailed
            }
            return false
        }
    }

    func updateTransaction(_ transaction: Transaction) async -> Bool {
        do {
            try modelContext.save()

            await MainActor.run {
                if let index = self.transactions.firstIndex(where: { $0.id == transaction.id }) {
                    self.transactions[index] = transaction
                }
            }
            await updateBudgetSpending()
            return true
        } catch {
            await MainActor.run {
                self.error = .transactionSaveFailed
            }
            return false
        }
    }

    func deleteTransaction(_ transaction: Transaction) async -> Bool {
        do {
            modelContext.delete(transaction)
            try modelContext.save()

            await MainActor.run {
                self.transactions.removeAll { $0.id == transaction.id }
            }
            await updateBudgetSpending()
            return true
        } catch {
            await MainActor.run {
                self.error = .transactionSaveFailed
            }
            return false
        }
    }

    // MARK: - Budget Operations

    func saveBudget(_ budget: Budget) async -> Bool {
        do {
            // Check if budget already exists
            let descriptor = FetchDescriptor<Budget>(predicate: #Predicate { $0.categoryRaw == budget.category.rawValue })
            let existingBudgets = try modelContext.fetch(descriptor)

            if let existingBudget = existingBudgets.first {
                // Update existing budget
                existingBudget.monthlyLimit = budget.monthlyLimit
                existingBudget.currentSpent = budget.currentSpent
                existingBudget.alertThreshold = budget.alertThreshold
            } else {
                // Insert new budget
                modelContext.insert(budget)
            }

            try modelContext.save()

            await MainActor.run {
                if let index = self.budgets.firstIndex(where: { $0.category == budget.category }) {
                    self.budgets[index] = budget
                } else {
                    self.budgets.append(budget)
                }
            }
            return true
        } catch {
            await MainActor.run {
                self.error = .budgetSaveFailed
            }
            return false
        }
    }

    func deleteBudget(_ budget: Budget) async -> Bool {
        do {
            modelContext.delete(budget)
            try modelContext.save()

            await MainActor.run {
                self.budgets.removeAll { $0.id == budget.id }
            }
            return true
        } catch {
            await MainActor.run {
                self.error = .budgetSaveFailed
            }
            return false
        }
    }

    // MARK: - Budget Analysis

    private func updateBudgetForTransaction(_ transaction: Transaction) async {
        guard transaction.amount > 0 else { return } // Only count positive amounts (debits) towards budget

        if let budgetIndex = budgets.firstIndex(where: { $0.category == transaction.category }) {
            await MainActor.run {
                budgets[budgetIndex].updateSpentAmount(by: transaction.amount)
            }

            do {
                try modelContext.save()
            } catch {
                await MainActor.run {
                    self.error = .budgetSaveFailed
                }
            }
        }
    }

    private func updateBudgetSpending() async {
        let calendar = Calendar.current
        let currentMonth = calendar.dateInterval(of: .month, for: Date())

        var updatedBudgets: [Budget] = []

        for budget in budgets {
            let categoryTransactions = transactions.filter { transaction in
                transaction.category == budget.category &&
                transaction.amount > 0 && // Only count debits
                currentMonth?.contains(transaction.date) == true
            }

            let totalSpent = categoryTransactions.reduce(Decimal(0)) { $0 + $1.amount }

            budget.currentSpent = totalSpent
            updatedBudgets.append(budget)
        }

        // Perform a single batched save for all updated budgets
        do {
            try modelContext.save()

            await MainActor.run {
                // Update the local budgets array
                for updatedBudget in updatedBudgets {
                    if let index = self.budgets.firstIndex(where: { $0.id == updatedBudget.id }) {
                        self.budgets[index] = updatedBudget
                    }
                }
            }
        } catch {
            await MainActor.run {
                self.error = .budgetSaveFailed
            }
        }
    }

    func calculateCategorySpending(for category: TransactionCategory, in dateInterval: DateInterval) -> Decimal {
        return transactions
            .filter { transaction in
                transaction.category == category &&
                transaction.amount > 0 &&
                dateInterval.contains(transaction.date)
            }
            .reduce(Decimal(0)) { $0 + $1.amount }
    }

    func getMonthlySpending(for date: Date = Date()) -> [TransactionCategory: Decimal] {
        let calendar = Calendar.current
        guard let monthInterval = calendar.dateInterval(of: .month, for: date) else {
            return [:]
        }

        var categorySpending: [TransactionCategory: Decimal] = [:]

        for category in TransactionCategory.allCases {
            let spending = calculateCategorySpending(for: category, in: monthInterval)
            if spending > 0 {
                categorySpending[category] = spending
            }
        }

        return categorySpending
    }

    func getBudgetStatus() -> [Budget.Status: Int] {
        let statusCounts = budgets.reduce(into: [Budget.Status: Int]()) { result, budget in
            result[budget.status, default: 0] += 1
        }
        return statusCounts
    }

    // MARK: - Data Export

    func exportTransactionsAsJSON() async -> Data? {
        do {
            // Convert Transaction classes to a simple structure for JSON encoding
            let exportableTransactions = transactions.map { transaction in
                [
                    "id": transaction.id.uuidString,
                    "amount": NSDecimalNumber(decimal: transaction.amount).doubleValue,
                    "description": transaction.description,
                    "category": transaction.category.rawValue,
                    "date": transaction.date.timeIntervalSince1970,
                    "accountId": transaction.accountId
                ]
            }
            return try JSONSerialization.data(withJSONObject: exportableTransactions)
        } catch {
            await MainActor.run {
                self.error = .invalidData
            }
            return nil
        }
    }

    func exportBudgetsAsJSON() async -> Data? {
        do {
            // Convert Budget classes to a simple structure for JSON encoding
            let exportableBudgets = budgets.map { budget in
                [
                    "id": budget.id.uuidString,
                    "category": budget.category.rawValue,
                    "monthlyLimit": NSDecimalNumber(decimal: budget.monthlyLimit).doubleValue,
                    "currentSpent": NSDecimalNumber(decimal: budget.currentSpent).doubleValue,
                    "alertThreshold": budget.alertThreshold
                ]
            }
            return try JSONSerialization.data(withJSONObject: exportableBudgets)
        } catch {
            await MainActor.run {
                self.error = .invalidData
            }
            return nil
        }
    }

    // MARK: - Sample Data

    func loadSampleData() async {
        // Load sample transactions
        for sampleTransaction in Transaction.sampleTransactions() {
            _ = await saveTransaction(sampleTransaction)
        }

        // Load sample budgets
        for sampleBudget in Budget.sampleBudgets() {
            _ = await saveBudget(sampleBudget)
        }

        await loadAllData()
    }

    func clearAllData() async {
        do {
            // Delete all transactions
            try modelContext.delete(model: Transaction.self)

            // Delete all budgets
            try modelContext.delete(model: Budget.self)

            try modelContext.save()

            await MainActor.run {
                self.transactions.removeAll()
                self.budgets.removeAll()
            }
        } catch {
            await MainActor.run {
                self.error = .invalidData
            }
        }
    }
}