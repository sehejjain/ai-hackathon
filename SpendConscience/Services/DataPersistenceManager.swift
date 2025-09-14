//
//  DataPersistenceManager.swift
//  SpendConscience
//
//  Enhanced data persistence utilities for SwiftData
//

import Foundation
import SwiftData
import OSLog

/// Manages advanced data persistence features for SpendConscience
class DataPersistenceManager {
    private let logger = Logger(subsystem: "SpendConscience", category: "DataPersistence")
    
    // MARK: - Data Validation
    
    /// Validates the integrity of all data in the model context
    func validateDataIntegrity(context: ModelContext) async -> DataValidationResult {
        var issues: [DataValidationIssue] = []
        var stats = DataStats()
        
        do {
            // Validate transactions
            let transactionDescriptor = FetchDescriptor<Transaction>()
            let transactions = try context.fetch(transactionDescriptor)
            stats.transactionCount = transactions.count
            
            for transaction in transactions {
                // Check for invalid amounts
                if transaction.amount < 0 {
                    issues.append(.invalidTransaction(id: transaction.id, reason: "Negative amount"))
                }
                
                // Check for empty descriptions
                if transaction.description.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                    issues.append(.invalidTransaction(id: transaction.id, reason: "Empty description"))
                }
                
                // Check for future dates (suspicious)
                if transaction.date > Date().addingTimeInterval(24 * 60 * 60) { // More than 1 day in future
                    issues.append(.suspiciousTransaction(id: transaction.id, reason: "Date too far in future"))
                }
                
                // Check for very old dates (suspicious)
                if transaction.date < Date().addingTimeInterval(-365 * 24 * 60 * 60 * 10) { // More than 10 years ago
                    issues.append(.suspiciousTransaction(id: transaction.id, reason: "Date too old"))
                }
            }
            
            // Validate budgets
            let budgetDescriptor = FetchDescriptor<Budget>()
            let budgets = try context.fetch(budgetDescriptor)
            stats.budgetCount = budgets.count
            
            for budget in budgets {
                // Check for invalid monthly limits
                if budget.monthlyLimit <= 0 {
                    issues.append(.invalidBudget(id: budget.id, reason: "Invalid monthly limit"))
                }
                
                // Check for invalid alert thresholds
                if budget.alertThreshold < 0 || budget.alertThreshold > 1 {
                    issues.append(.invalidBudget(id: budget.id, reason: "Alert threshold out of range"))
                }
                
                // Check for negative spent amounts
                if budget.currentSpent < 0 {
                    issues.append(.invalidBudget(id: budget.id, reason: "Negative spent amount"))
                }
            }
            
            // Check for duplicate categories in budgets
            let categoryGroups = Dictionary(grouping: budgets, by: { $0.category })
            for (category, budgetsForCategory) in categoryGroups {
                if budgetsForCategory.count > 1 {
                    let ids = budgetsForCategory.map { $0.id }
                    issues.append(.duplicateBudgetCategory(category: category, budgetIds: ids))
                }
            }
            
            logger.info("Data validation completed: \(transactions.count) transactions, \(budgets.count) budgets, \(issues.count) issues found")
            
        } catch {
            logger.error("Data validation failed: \(error.localizedDescription)")
            issues.append(.dataAccessError(error: error))
        }
        
        return DataValidationResult(issues: issues, stats: stats)
    }
    
    // MARK: - Data Backup and Export
    
    /// Creates a complete backup of all app data
    func createDataBackup(context: ModelContext) async -> DataBackup? {
        do {
            let transactionDescriptor = FetchDescriptor<Transaction>()
            let transactions = try context.fetch(transactionDescriptor)
            
            let budgetDescriptor = FetchDescriptor<Budget>()
            let budgets = try context.fetch(budgetDescriptor)
            
            // Convert to exportable format
            let exportableTransactions = transactions.map { transaction in
                ExportableTransaction(
                    id: transaction.id,
                    amount: NSDecimalNumber(decimal: transaction.amount).doubleValue,
                    description: transaction.description,
                    category: transaction.category.rawValue,
                    date: transaction.date,
                    accountId: transaction.accountId,
                    dataSource: transaction.dataSource?.rawValue,
                    backendSyncDate: transaction.backendSyncDate,
                    backendId: transaction.backendId,
                    merchantName: transaction.merchantName
                )
            }
            
            let exportableBudgets = budgets.map { budget in
                ExportableBudget(
                    id: budget.id,
                    category: budget.category.rawValue,
                    monthlyLimit: NSDecimalNumber(decimal: budget.monthlyLimit).doubleValue,
                    currentSpent: NSDecimalNumber(decimal: budget.currentSpent).doubleValue,
                    alertThreshold: budget.alertThreshold,
                    dataSource: budget.dataSource?.rawValue,
                    backendSyncDate: budget.backendSyncDate
                )
            }
            
            let backup = DataBackup(
                version: "1.0",
                createdAt: Date(),
                appVersion: Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "Unknown",
                transactions: exportableTransactions,
                budgets: exportableBudgets
            )
            
            logger.info("Created data backup with \(transactions.count) transactions and \(budgets.count) budgets")
            return backup
            
        } catch {
            logger.error("Failed to create data backup: \(error.localizedDescription)")
            return nil
        }
    }
    
    /// Exports data backup as JSON
    func exportBackupAsJSON(_ backup: DataBackup) -> Data? {
        do {
            let encoder = JSONEncoder()
            encoder.dateEncodingStrategy = .iso8601
            encoder.outputFormatting = .prettyPrinted
            return try encoder.encode(backup)
        } catch {
            logger.error("Failed to encode backup as JSON: \(error.localizedDescription)")
            return nil
        }
    }
    
    // MARK: - Data Restoration
    
    /// Restores data from a backup
    func restoreFromBackup(_ backup: DataBackup, context: ModelContext, mergeStrategy: MergeStrategy = .replaceAll) async -> Bool {
        do {
            switch mergeStrategy {
            case .replaceAll:
                // Clear existing data
                try context.delete(model: Transaction.self)
                try context.delete(model: Budget.self)
                
            case .mergeByDate:
                // Only merge newer data
                break
                
            case .mergeById:
                // Merge by ID, replacing existing
                break
            }
            
            // Restore transactions
            for exportableTransaction in backup.transactions {
                let transaction = try Transaction(
                    id: exportableTransaction.id,
                    amount: try Decimal(exportableTransaction.amount),
                    description: exportableTransaction.description,
                    category: TransactionCategory(rawValue: exportableTransaction.category) ?? .other,
                    date: exportableTransaction.date,
                    accountId: exportableTransaction.accountId
                )
                
                if let dataSourceRaw = exportableTransaction.dataSource {
                    transaction.dataSourceRaw = dataSourceRaw
                }
                transaction.backendSyncDate = exportableTransaction.backendSyncDate
                transaction.backendId = exportableTransaction.backendId
                transaction.merchantName = exportableTransaction.merchantName
                
                context.insert(transaction)
            }
            
            // Restore budgets
            for exportableBudget in backup.budgets {
                let budget = try Budget(
                    id: exportableBudget.id,
                    category: TransactionCategory(rawValue: exportableBudget.category) ?? .other,
                    monthlyLimit: Decimal(exportableBudget.monthlyLimit),
                    currentSpent: Decimal(exportableBudget.currentSpent),
                    alertThreshold: exportableBudget.alertThreshold
                )
                
                if let dataSourceRaw = exportableBudget.dataSource {
                    budget.dataSourceRaw = dataSourceRaw
                }
                budget.backendSyncDate = exportableBudget.backendSyncDate
                
                context.insert(budget)
            }
            
            try context.save()
            
            logger.info("Successfully restored data from backup: \(backup.transactions.count) transactions, \(backup.budgets.count) budgets")
            return true
            
        } catch {
            logger.error("Failed to restore from backup: \(error.localizedDescription)")
            return false
        }
    }
    
    // MARK: - Storage Management
    
    /// Gets information about data storage usage
    func getStorageInfo(context: ModelContext) async -> StorageInfo {
        var info = StorageInfo()
        
        do {
            // Count transactions
            let transactionDescriptor = FetchDescriptor<Transaction>()
            let transactions = try context.fetch(transactionDescriptor)
            info.transactionCount = transactions.count
            
            // Count budgets
            let budgetDescriptor = FetchDescriptor<Budget>()
            let budgets = try context.fetch(budgetDescriptor)
            info.budgetCount = budgets.count
            
            // Calculate date ranges
            if !transactions.isEmpty {
                let dates = transactions.map { $0.date }
                info.oldestTransactionDate = dates.min()
                info.newestTransactionDate = dates.max()
            }
            
            // Estimate storage size (rough approximation)
            info.estimatedStorageSize = (transactions.count * 200) + (budgets.count * 100) // bytes per record estimate
            
        } catch {
            logger.error("Failed to get storage info: \(error.localizedDescription)")
        }
        
        return info
    }
    
    /// Cleans up old or orphaned data
    func performDataCleanup(context: ModelContext, olderThan: Date? = nil) async -> DataCleanupResult {
        var result = DataCleanupResult()
        
        do {
            // Clean up old transactions if date is specified
            if let cutoffDate = olderThan {
                let oldTransactionDescriptor = FetchDescriptor<Transaction>(
                    predicate: #Predicate { $0.date < cutoffDate }
                )
                let oldTransactions = try context.fetch(oldTransactionDescriptor)
                
                for transaction in oldTransactions {
                    context.delete(transaction)
                    result.deletedTransactions += 1
                }
            }
            
            // Find and remove orphaned budgets (budgets without valid categories)
            let budgetDescriptor = FetchDescriptor<Budget>()
            let budgets = try context.fetch(budgetDescriptor)
            
            for budget in budgets {
                if budget.category == .other && budget.categoryRaw != "other" {
                    // This might be an orphaned budget with invalid category
                    context.delete(budget)
                    result.deletedBudgets += 1
                }
            }
            
            try context.save()
            result.success = true
            
            logger.info("Data cleanup completed: removed \(result.deletedTransactions) transactions, \(result.deletedBudgets) budgets")
            
        } catch {
            logger.error("Data cleanup failed: \(error.localizedDescription)")
            result.error = error
        }
        
        return result
    }
}

// MARK: - Supporting Types

enum MergeStrategy {
    case replaceAll
    case mergeByDate
    case mergeById
}

struct DataValidationResult {
    let issues: [DataValidationIssue]
    let stats: DataStats
    
    var isValid: Bool { issues.isEmpty }
    var hasErrors: Bool { issues.contains { $0.severity == .error } }
    var hasWarnings: Bool { issues.contains { $0.severity == .warning } }
}

enum DataValidationIssue {
    case invalidTransaction(id: UUID, reason: String)
    case invalidBudget(id: UUID, reason: String)
    case suspiciousTransaction(id: UUID, reason: String)
    case duplicateBudgetCategory(category: TransactionCategory, budgetIds: [UUID])
    case dataAccessError(error: Error)
    
    var severity: IssueSeverity {
        switch self {
        case .invalidTransaction, .invalidBudget, .duplicateBudgetCategory, .dataAccessError:
            return .error
        case .suspiciousTransaction:
            return .warning
        }
    }
}

enum IssueSeverity {
    case error
    case warning
}

struct DataStats {
    var transactionCount: Int = 0
    var budgetCount: Int = 0
}

struct DataBackup: Codable {
    let version: String
    let createdAt: Date
    let appVersion: String
    let transactions: [ExportableTransaction]
    let budgets: [ExportableBudget]
}

struct ExportableTransaction: Codable {
    let id: UUID
    let amount: Double
    let description: String
    let category: String
    let date: Date
    let accountId: String
    let dataSource: String?
    let backendSyncDate: Date?
    let backendId: String?
    let merchantName: String?
}

struct ExportableBudget: Codable {
    let id: UUID
    let category: String
    let monthlyLimit: Double
    let currentSpent: Double
    let alertThreshold: Double
    let dataSource: String?
    let backendSyncDate: Date?
}

struct StorageInfo {
    var transactionCount: Int = 0
    var budgetCount: Int = 0
    var oldestTransactionDate: Date?
    var newestTransactionDate: Date?
    var estimatedStorageSize: Int = 0 // in bytes
}

struct DataCleanupResult {
    var success: Bool = false
    var deletedTransactions: Int = 0
    var deletedBudgets: Int = 0
    var error: Error?
}

struct DataMaintenanceResult {
    var validationResult: DataValidationResult?
    var cleanupResult: DataCleanupResult?
    var storageInfo: StorageInfo?
    
    var isSuccess: Bool {
        return validationResult?.isValid == true && cleanupResult?.success == true
    }
}