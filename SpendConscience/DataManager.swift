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
    let apiService: SpendConscienceAPIService
    private let persistenceManager = DataPersistenceManager()
    let errorRecoveryManager = ErrorRecoveryManager()
    
    // Helper method to get last successful backend sync time
    func getLastBackendSyncTime() -> Date? {
        // Find the most recent backend sync date from all transactions
        return transactions
            .compactMap { $0.backendSyncDate }
            .max()
    }
    
    // Helper method to get last successful backend budget sync time
    func getLastBudgetBackendSyncTime() -> Date? {
        // Find the most recent backend sync date from all budgets
        return budgets
            .compactMap { $0.backendSyncDate }
            .max()
    }

    enum DataError: Error, LocalizedError {
        case transactionSaveFailed
        case transactionLoadFailed
        case budgetSaveFailed
        case budgetLoadFailed
        case invalidData
        case contextUnavailable
        case backendConnectionFailed
        case backendDataConversionFailed
        case backendBudgetConnectionFailed
        case backendBudgetDataConversionFailed
        case apiServiceError(String)

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
            case .backendConnectionFailed:
                return "Failed to connect to backend AI service"
            case .backendDataConversionFailed:
                return "Failed to convert backend data to local format"
            case .backendBudgetConnectionFailed:
                return "Failed to connect to backend AI service for budget data"
            case .backendBudgetDataConversionFailed:
                return "Failed to convert backend budget data to local format"
            case .apiServiceError(let message):
                return "API Service Error: \(message)"
            }
        }
    }

    private var loadTask: Task<Void, Never>?

    init(modelContext: ModelContext) {
        self.modelContext = modelContext
        self.apiService = SpendConscienceAPIService()
        
        // Setup error recovery notifications
        setupErrorRecoveryNotifications()
        
        loadTask = Task { [weak self] in
            await self?.loadAllData()
        }
    }

    deinit {
        loadTask?.cancel()
        NotificationCenter.default.removeObserver(self)
    }
    
    // MARK: - Error Recovery Setup
    
    private func setupErrorRecoveryNotifications() {
        NotificationCenter.default.addObserver(
            forName: .refreshAllData,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            Task { @MainActor in
                await self?.loadAllData()
            }
        }
        
        NotificationCenter.default.addObserver(
            forName: .clearAppCache,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            Task { @MainActor in
                await self?.clearLocalCache()
            }
        }
        
        NotificationCenter.default.addObserver(
            forName: .refreshPlaidConnection,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            Task { @MainActor in
                await self?.refreshPlaidConnection()
            }
        }
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
        // First attempt to fetch from backend AI service
        do {
            print("DataManager: Attempting to fetch transactions from backend AI service")
            let backendTransactions = await apiService.fetchTransactionData()
            
            // Check for API service errors and handle with error recovery
            if let apiError = apiService.currentError {
                await MainActor.run {
                    self.error = .apiServiceError(apiError.localizedDescription)
                    self.errorRecoveryManager.handleError(apiError, context: "Backend transaction fetch")
                }
                // Still fall back to local data
                await loadLocalTransactions()
                return
            }
            
            // Handle empty backend response by falling back to local cache
            if backendTransactions.isEmpty {
                print("DataManager: Empty backend response, falling back to local cache")
                await loadLocalTransactions()
                return
            }
            
            // Convert backend transactions to local Transaction models
            var convertedTransactions: [Transaction] = []
            var failedConversions = 0
            
            for backendTransaction in backendTransactions {
                if let localTransaction = backendTransaction.toLocalTransaction() {
                    convertedTransactions.append(localTransaction)
                    
                    // Optionally save to SwiftData for offline access
                    modelContext.insert(localTransaction)
                } else {
                    failedConversions += 1
                }
            }
            
            // Count failed conversions and handle conversion errors
            if backendTransactions.count > 0 && convertedTransactions.isEmpty {
                print("DataManager: All backend transactions failed conversion (\(failedConversions) failed)")
                await MainActor.run {
                    self.error = .backendDataConversionFailed
                }
                // Fall back to local fetch
                do {
                    print("DataManager: Loading transactions from local SwiftData after conversion failure")
                    let descriptor = FetchDescriptor<Transaction>(
                        sortBy: [SortDescriptor(\.date, order: .reverse)]
                    )
                    let loadedTransactions = try modelContext.fetch(descriptor)

                    await MainActor.run {
                        self.transactions = loadedTransactions
                    }
                    print("DataManager: Successfully loaded \(loadedTransactions.count) transactions from local storage")
                } catch {
                    print("DataManager: Local transaction loading failed: \(error)")
                    await MainActor.run {
                        self.error = .transactionLoadFailed
                    }
                }
                return
            }
            
            if failedConversions > 0 {
                print("DataManager: \(failedConversions) out of \(backendTransactions.count) backend transactions failed conversion")
            }
            
            try modelContext.save()
            
            await MainActor.run {
                self.transactions = convertedTransactions.sorted { $0.date > $1.date }
            }
            
            print("DataManager: Successfully loaded \(convertedTransactions.count) transactions from backend (\(failedConversions) failed conversions)")
            return
            
        } catch {
            print("DataManager: Backend fetch failed, falling back to local data: \(error)")
            await MainActor.run {
                self.error = .backendConnectionFailed
            }
        }
        
        // Fallback to local SwiftData if backend fails
        do {
            print("DataManager: Loading transactions from local SwiftData")
            let descriptor = FetchDescriptor<Transaction>(
                sortBy: [SortDescriptor(\.date, order: .reverse)]
            )
            let loadedTransactions = try modelContext.fetch(descriptor)

            await MainActor.run {
                self.transactions = loadedTransactions
            }
            print("DataManager: Successfully loaded \(loadedTransactions.count) transactions from local storage")
        } catch {
            print("DataManager: Local transaction loading failed: \(error)")
            await MainActor.run {
                self.error = .transactionLoadFailed
            }
        }
    }

    func syncWithBackend() async {
        print("DataManager: Starting backend sync")
        isLoading = true
        error = nil
        
        do {
            let backendTransactions = await apiService.fetchTransactionData()
            
            // 1) Fetch existing transactions
            let descriptor = FetchDescriptor<Transaction>()
            let existingTransactions = try modelContext.fetch(descriptor)
            
            // 2) Map existing transactions by backend ID
            var existingByBackendId: [String: Transaction] = [:]
            for transaction in existingTransactions {
                if let backendId = transaction.backendId {
                    existingByBackendId[backendId] = transaction
                }
            }
            
            // 3) For each backend transaction, upsert using Transaction(from:) or mergeWithBackendData
            var processedBackendIds: Set<String> = []
            for backendTransaction in backendTransactions {
                processedBackendIds.insert(backendTransaction.id)
                
                if let existingTransaction = existingByBackendId[backendTransaction.id] {
                    // Update existing transaction
                    existingTransaction.mergeWithBackendData(backendTransaction)
                } else {
                    // Create new transaction
                    if let newTransaction = try? Transaction(from: backendTransaction) {
                        modelContext.insert(newTransaction)
                    }
                }
            }
            
            // 4) Mark stale backend transactions (optional - only if needed)
            // For now, we'll keep all local transactions to avoid losing user edits
            
            try modelContext.save()
            
            // Reload transactions from database
            let updatedDescriptor = FetchDescriptor<Transaction>(
                sortBy: [SortDescriptor(\.date, order: .reverse)]
            )
            let updatedTransactions = try modelContext.fetch(updatedDescriptor)
            
            await MainActor.run {
                self.transactions = updatedTransactions
                self.isLoading = false
            }
            
            await updateBudgetSpending()
            print("DataManager: Backend sync completed successfully with \(backendTransactions.count) backend transactions")
            
        } catch {
            print("DataManager: Backend sync failed: \(error)")
            await MainActor.run {
                self.error = .backendConnectionFailed
                self.isLoading = false
            }
        }
    }

    private func loadBudgets() async {
        // First attempt to fetch from backend AI service
        do {
            print("DataManager: Attempting to fetch budget insights from backend AI service")
            let backendBudgets = await apiService.fetchBudgetInsights()
            
            // Check for API service errors and surface them
            if let apiError = apiService.currentError {
                print("DataManager: API error for budget insights: \(apiError.localizedDescription)")
                // Fall back to local data without setting error since we already have transaction error handling
                do {
                    print("DataManager: Loading budgets from local SwiftData after API error")
                    let descriptor = FetchDescriptor<Budget>()
                    let loadedBudgets = try modelContext.fetch(descriptor)

                    await MainActor.run {
                        self.budgets = loadedBudgets
                    }
                    print("DataManager: Successfully loaded \(loadedBudgets.count) budgets from local storage")
                } catch {
                    print("DataManager: Local budget loading failed: \(error)")
                    await MainActor.run {
                        self.error = .budgetLoadFailed
                    }
                }
                return
            }
            
            // Handle empty backend response by falling back to local cache
            if backendBudgets.isEmpty {
                print("DataManager: Empty backend budget response, falling back to local cache")
                do {
                    print("DataManager: Loading budgets from local SwiftData")
                    let descriptor = FetchDescriptor<Budget>()
                    let loadedBudgets = try modelContext.fetch(descriptor)

                    await MainActor.run {
                        self.budgets = loadedBudgets
                    }
                    print("DataManager: Successfully loaded \(loadedBudgets.count) budgets from local storage")
                } catch {
                    print("DataManager: Local budget loading failed: \(error)")
                    await MainActor.run {
                        self.error = .budgetLoadFailed
                    }
                }
                return
            }
            
            print("DataManager: Received \(backendBudgets.count) budgets from backend, converting to local format")
            
            // Convert backend budgets to local Budget models
            var convertedBudgets: [Budget] = []
            var failedConversions = 0
            
            for backendBudget in backendBudgets {
                if let localBudget = backendBudget.toLocalBudget() {
                    convertedBudgets.append(localBudget)
                    
                    // Save to SwiftData for offline access
                    modelContext.insert(localBudget)
                } else {
                    failedConversions += 1
                    print("DataManager: Failed to convert budget: \(backendBudget)")
                }
            }
            
            // Count failed conversions and handle conversion errors
            if backendBudgets.count > 0 && convertedBudgets.isEmpty {
                print("DataManager: All backend budgets failed conversion (\(failedConversions) failed)")
                await MainActor.run {
                    self.error = .backendBudgetDataConversionFailed
                }
                // Fall back to local fetch
                do {
                    print("DataManager: Loading budgets from local SwiftData after conversion failure")
                    let descriptor = FetchDescriptor<Budget>()
                    let loadedBudgets = try modelContext.fetch(descriptor)

                    await MainActor.run {
                        self.budgets = loadedBudgets
                    }
                    print("DataManager: Successfully loaded \(loadedBudgets.count) budgets from local storage")
                } catch {
                    print("DataManager: Local budget loading failed: \(error)")
                    await MainActor.run {
                        self.error = .budgetLoadFailed
                    }
                }
                return
            }
            
            if failedConversions > 0 {
                print("DataManager: \(failedConversions) out of \(backendBudgets.count) backend budgets failed conversion")
            }
            
            try modelContext.save()
            
            await MainActor.run {
                self.budgets = convertedBudgets
            }
            
            print("DataManager: Successfully loaded \(convertedBudgets.count) budgets from backend (\(failedConversions) failed conversions)")
            return
            
        } catch {
            print("DataManager: Backend budget fetch failed, falling back to local data: \(error)")
            await MainActor.run {
                self.error = .backendBudgetConnectionFailed
            }
        }
        
        // Fallback to local SwiftData if backend fails
        do {
            print("DataManager: Loading budgets from local SwiftData")
            let descriptor = FetchDescriptor<Budget>()
            let loadedBudgets = try modelContext.fetch(descriptor)

            await MainActor.run {
                self.budgets = loadedBudgets
            }
            print("DataManager: Successfully loaded \(loadedBudgets.count) budgets from local storage")
        } catch {
            print("DataManager: Local budget loading failed: \(error)")
            await MainActor.run {
                self.error = .budgetLoadFailed
            }
        }
    }
    
    func syncBudgetsWithBackend() async {
        print("DataManager: Starting backend budget sync")
        isLoading = true
        error = nil
        
        do {
            let backendBudgets = await apiService.fetchBudgetInsights()
            
            // 1) Fetch existing budgets
            let descriptor = FetchDescriptor<Budget>()
            let existingBudgets = try modelContext.fetch(descriptor)
            
            // 2) Map existing budgets by category
            var existingByCategory: [String: Budget] = [:]
            for budget in existingBudgets {
                existingByCategory[budget.categoryRaw] = budget
            }
            
            // 3) For each backend budget, upsert using mergeWithBackendData
            for backendBudget in backendBudgets {
                if let existingBudget = existingByCategory[backendBudget.category] {
                    // Update existing budget with AI data
                    existingBudget.mergeWithBackendData(backendBudget)
                } else {
                    // Create new budget from AI data
                    if let newBudget = backendBudget.toLocalBudget() {
                        modelContext.insert(newBudget)
                    }
                }
            }
            
            try modelContext.save()
            
            // Reload budgets from database
            let updatedDescriptor = FetchDescriptor<Budget>()
            let updatedBudgets = try modelContext.fetch(updatedDescriptor)
            
            await MainActor.run {
                self.budgets = updatedBudgets
                self.isLoading = false
            }
            
            print("DataManager: Backend budget sync completed successfully with \(backendBudgets.count) backend budgets")
            
        } catch {
            print("DataManager: Backend budget sync failed: \(error)")
            await MainActor.run {
                self.error = .backendBudgetConnectionFailed
                self.isLoading = false
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
            let categoryRaw = budget.categoryRaw
            let descriptor = FetchDescriptor<Budget>(predicate: #Predicate { $0.categoryRaw == categoryRaw })
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
    
    func updateBudget(_ budget: Budget) async -> Bool {
        do {
            // Since the budget object is already managed by SwiftData,
            // we just need to save the context after modifications
            try modelContext.save()

            await MainActor.run {
                // Refresh the local array to reflect changes
                if let index = self.budgets.firstIndex(where: { $0.id == budget.id }) {
                    self.budgets[index] = budget
                }
            }
            
            // Recalculate budget spending after the update
            await updateBudgetSpending()
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
        guard transaction.amount > 0 else { return } // Only count positive amounts (spending/debits) towards budget, as per Transaction model
        
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
            // Check if budget has recent backend sync data
            let hasRecentBackendData = budget.backendSyncDate != nil && 
                                     budget.backendSyncDate! > Date().addingTimeInterval(-3600) // Within last hour
            
            // Skip local recalculation if we have recent AI data
            if hasRecentBackendData && budget.isFromBackend {
                print("DataManager: Skipping local spending calculation for \(budget.category.rawValue) - using AI data")
                updatedBudgets.append(budget)
                continue
            }
            
            // Calculate spending locally for budgets without recent AI data
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

    // MARK: - Helper Methods for Views
    
    func getBudgetByID(_ id: UUID) -> Budget? {
        return budgets.first { $0.id == id }
    }
    
    func getTransactionByID(_ id: UUID) -> Transaction? {
        return transactions.first { $0.id == id }
    }
    
    func getTransactionsForCategory(_ category: TransactionCategory, limit: Int? = nil) -> [Transaction] {
        let filtered = transactions.filter { $0.category == category }
        if let limit = limit {
            return Array(filtered.prefix(limit))
        }
        return filtered
    }
    
    func getWeeklySpendingForCategory(_ category: TransactionCategory, reference: Date = Date()) -> Decimal {
        let calendar = Calendar.current
        let weekStart = calendar.dateInterval(of: .weekOfYear, for: reference)?.start ?? reference
        let weekEnd = calendar.date(byAdding: .day, value: 7, to: weekStart) ?? reference
        
        return transactions
            .filter { transaction in
                transaction.category == category &&
                transaction.amount > 0 &&
                transaction.date >= weekStart &&
                transaction.date < weekEnd
            }
            .reduce(Decimal(0)) { $0 + $1.amount }
    }
    
    func getBudgetForCategory(_ category: TransactionCategory) -> Budget? {
        return budgets.first { $0.category == category }
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
    
    // MARK: - Enhanced Data Persistence Methods
    
    /// Validates the integrity of all data
    func validateDataIntegrity() async -> DataValidationResult {
        return await persistenceManager.validateDataIntegrity(context: modelContext)
    }
    
    /// Creates a backup of all app data
    func createDataBackup() async -> DataBackup? {
        return await persistenceManager.createDataBackup(context: modelContext)
    }
    
    /// Exports data backup as JSON
    func exportDataAsJSON() async -> Data? {
        if let backup = await createDataBackup() {
            return persistenceManager.exportBackupAsJSON(backup)
        }
        return nil
    }
    
    /// Restores data from a backup
    func restoreFromBackup(_ backup: DataBackup, mergeStrategy: MergeStrategy = .replaceAll) async -> Bool {
        let success = await persistenceManager.restoreFromBackup(backup, context: modelContext, mergeStrategy: mergeStrategy)
        if success {
            // Reload data after restoration
            await loadAllData()
        }
        return success
    }
    
    /// Gets storage information
    func getStorageInfo() async -> StorageInfo {
        return await persistenceManager.getStorageInfo(context: modelContext)
    }
    
    /// Performs data cleanup
    func performDataCleanup(olderThan: Date? = nil) async -> DataCleanupResult {
        let result = await persistenceManager.performDataCleanup(context: modelContext, olderThan: olderThan)
        if result.success {
            // Reload data after cleanup
            await loadAllData()
        }
        return result
    }
    
    /// Performs automatic maintenance (validation + cleanup)
    func performDataMaintenance() async -> DataMaintenanceResult {
        var result = DataMaintenanceResult()
        
        // Step 1: Validate data integrity
        result.validationResult = await validateDataIntegrity()
        
        // Step 2: Clean up old data (older than 2 years)
        let twoYearsAgo = Calendar.current.date(byAdding: .year, value: -2, to: Date()) ?? Date()
        result.cleanupResult = await performDataCleanup(olderThan: twoYearsAgo)
        
        // Step 3: Get final storage info
        result.storageInfo = await getStorageInfo()
        
        return result
    }
    
    // MARK: - Error Recovery Helper Methods
    
    private func loadLocalTransactions() async {
        do {
            print("DataManager: Loading transactions from local SwiftData")
            let descriptor = FetchDescriptor<Transaction>(
                sortBy: [SortDescriptor(\.date, order: .reverse)]
            )
            let loadedTransactions = try modelContext.fetch(descriptor)

            await MainActor.run {
                self.transactions = loadedTransactions
            }
            print("DataManager: Successfully loaded \(loadedTransactions.count) transactions from local storage")
        } catch {
            print("DataManager: Local transaction loading failed: \(error)")
            await MainActor.run {
                self.error = .transactionLoadFailed
                self.errorRecoveryManager.handleError(error, context: "Local transaction loading")
            }
        }
    }
    
    private func clearLocalCache() async {
        do {
            // Clear all local transactions and budgets
            try modelContext.delete(model: Transaction.self)
            try modelContext.delete(model: Budget.self)
            try modelContext.save()
            
            await MainActor.run {
                self.transactions = []
                self.budgets = []
            }
            
            print("DataManager: Local cache cleared successfully")
            
            // Reload data from backend
            await loadAllData()
        } catch {
            print("DataManager: Failed to clear local cache: \(error)")
            await MainActor.run {
                self.errorRecoveryManager.handleError(error, context: "Clear local cache")
            }
        }
    }
    
    private func refreshPlaidConnection() async {
        // This would trigger a Plaid reconnection flow
        // For now, just refresh the data
        print("DataManager: Refreshing Plaid connection")
        await loadAllData()
    }
}

#if DEBUG
extension DataManager {
    /// Creates a DataManager instance for SwiftUI previews with in-memory storage
    static func preview() -> DataManager {
        let config = ModelConfiguration(isStoredInMemoryOnly: true)
        let container = try! ModelContainer(for: Transaction.self, Budget.self, User.self, configurations: config)
        return DataManager(modelContext: container.mainContext)
    }
}
#endif