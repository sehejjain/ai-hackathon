//
//  TransactionStore.swift
//  SpendConscience
//
//  Bridge between Plaid API and SwiftData persistence layer
//

import Foundation
import SwiftData
import SwiftUI

// MARK: - Bridge for Plaid Integration

/// Bridge store for converting Plaid API data to SwiftData models
/// Note: This version is simplified to avoid naming conflicts between
/// Plaid Transaction/Account and SwiftData Transaction models
@MainActor
class TransactionStore: ObservableObject {
    
    // MARK: - Published Properties
    
    /// Loading state for store operations
    @Published var isLoading: Bool = false
    
    /// Current error state
    @Published var currentError: PlaidError?
    
    /// Store initialization status
    @Published var isInitialized: Bool = false
    
    /// Last sync timestamp
    @Published var lastSyncDate: Date?
    
    // MARK: - Private Properties
    
    /// SwiftData model context
    private let modelContext: ModelContext
    
    // MARK: - Initialization
    
    init(modelContext: ModelContext) {
        self.modelContext = modelContext
        isInitialized = true
        print("✅ TransactionStore: Bridge initialized with provided context")
    }
    
    // MARK: - PlaidService Integration Bridge
    
    /// Converts Plaid API responses to SwiftData models and saves them
    /// This method will be called by PlaidService with raw transaction data
    func syncPlaidTransactions(_ plaidTransactions: [PlaidTransaction]) async {
        guard isInitialized else {
            currentError = .invalidConfiguration
            return
        }
        
        isLoading = true
        defer { isLoading = false }
        
        // Convert PlaidTransaction structs to simple data tuples for processing
        let plaidTransactionData = plaidTransactions.map { tx in
            (
                id: tx.id,
                amount: tx.amount,
                date: tx.date,
                name: tx.name,
                category: tx.category ?? [], // Handle optional category with empty array default
                accountId: tx.accountId,
                merchantName: tx.merchantName,
                pending: tx.pending ?? false // Handle optional pending with false default
            )
        }
        
        await convertAndSaveTransactions(plaidTransactionData)
        
        lastSyncDate = Date()
        print("✅ TransactionStore: Synced \(plaidTransactions.count) Plaid transactions to SwiftData")
    }
    
    /// Converts Plaid transaction data to SwiftData Transaction models
    private func convertAndSaveTransactions(_ plaidTransactionData: [(
        id: String,
        amount: Double,
        date: Date,
        name: String,
        category: [String],
        accountId: String,
        merchantName: String?,
        pending: Bool
    )]) async {
        do {
            for plaidTx in plaidTransactionData {
                // Skip pending transactions
                if plaidTx.pending { continue }
                
                // Map Plaid category to our TransactionCategory
                let category = mapPlaidCategoryToTransactionCategory(plaidTx.category)
                
                // Convert amount (Plaid uses negative for expenses, we use positive)
                let amount = Decimal(abs(plaidTx.amount))
                
                // Check if transaction already exists (simple duplicate detection)
                // Fetch all transactions and filter in memory to avoid predicate macro issues
                let allTransactions = try modelContext.fetch(FetchDescriptor<Transaction>())
                
                // Filter for duplicates in memory
                let transactionExists = allTransactions.contains { existing in
                    existing.accountId == plaidTx.accountId &&
                    existing.amount == amount &&
                    existing.description.contains(plaidTx.name) &&
                    Calendar.current.isDate(existing.date, inSameDayAs: plaidTx.date)
                }
                
                if !transactionExists {
                    // Create new SwiftData Transaction
                    let transaction = try Transaction(
                        amount: amount,
                        description: plaidTx.name,
                        category: category,
                        date: plaidTx.date,
                        accountId: plaidTx.accountId
                    )
                    
                    modelContext.insert(transaction)
                }
            }
            
            try modelContext.save()
            print("✅ TransactionStore: Converted and saved Plaid transactions to SwiftData")
            
        } catch {
            handleError(.unknown("Failed to convert Plaid transactions: \(error.localizedDescription)"))
        }
    }
    
    /// Maps Plaid category array to our TransactionCategory enum
    private func mapPlaidCategoryToTransactionCategory(_ plaidCategories: [String]) -> TransactionCategory {
        // Plaid provides hierarchical categories, we'll map the primary category
        guard let primaryCategory = plaidCategories.first?.lowercased() else {
            return .other
        }
        
        // Map common Plaid categories to our categories
        switch primaryCategory {
        case "food and drink", "restaurants":
            return .dining
        case "shops", "general merchandise":
            return .shopping
        case "gas stations", "transportation":
            return .transportation
        case "utilities", "telecommunication services":
            return .utilities
        case "recreation", "entertainment":
            return .entertainment
        case "food and drink" where plaidCategories.contains("groceries"):
            return .groceries
        default:
            // Check secondary categories for more specific matches
            for category in plaidCategories {
                let lowerCategory = category.lowercased()
                if lowerCategory.contains("grocery") || lowerCategory.contains("supermarket") {
                    return .groceries
                } else if lowerCategory.contains("restaurant") || lowerCategory.contains("dining") {
                    return .dining
                } else if lowerCategory.contains("gas") || lowerCategory.contains("transport") {
                    return .transportation
                } else if lowerCategory.contains("entertainment") || lowerCategory.contains("movie") {
                    return .entertainment
                }
            }
            return .other
        }
    }
    
    // MARK: - Data Management
    
    /// Gets bridge statistics
    func getBridgeStats() -> Date? {
        return lastSyncDate
    }
    
    // MARK: - Error Handling
    
    /// Clears the current error state
    func clearError() {
        currentError = nil
    }
    
    /// Handles and logs errors appropriately
    private func handleError(_ error: PlaidError) {
        currentError = error
        isLoading = false
        
        print("❌ TransactionStore: Error occurred - \(error.localizedDescription)")
        
        // Log additional context based on error type
        switch error {
        case .invalidConfiguration:
            print("   💡 Hint: Check SwiftData initialization")
        default:
            break
        }
    }
}
