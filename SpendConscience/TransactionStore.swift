//
//  TransactionStore.swift
//  SpendConscience
//
//  SwiftData-based transaction store with persistent models and caching capabilities
//

import Foundation
import SwiftData
import SwiftUI

// MARK: - SwiftData Models

/// SwiftData model for category tags
@Model
class CategoryTag {
    @Attribute(.unique) var name: String
    var transactions: [StoredTransaction] = []
    
    init(name: String) {
        self.name = name
    }
}

/// SwiftData model for persistent transaction storage
@Model
class StoredTransaction {
    @Attribute(.unique) var id: String
    var amount: Double
    var date: Date
    var name: String
    var categoryTags: [CategoryTag] = []
    var category: [String] {
        get { categoryTags.map { $0.name } }
        set { 
            // This will be handled in the update methods
        }
    }
    var accountId: String
    var merchantName: String?
    var pending: Bool
    var transactionType: String
    var createdAt: Date
    var updatedAt: Date
    
    init(
        id: String,
        amount: Double,
        date: Date,
        name: String,
        category: [String],
        accountId: String,
        merchantName: String? = nil,
        pending: Bool,
        transactionType: String
    ) {
        self.id = id
        self.amount = amount
        self.date = date
        self.name = name
        self.accountId = accountId
        self.merchantName = merchantName
        self.pending = pending
        self.transactionType = transactionType
        self.createdAt = Date()
        self.updatedAt = Date()
        // Categories will be set after initialization
    }
    
    /// Converts SwiftData model to Plaid API model
    func toTransaction() -> Transaction {
        let transactionTypeEnum: Transaction.TransactionType
        switch transactionType {
        case "digital": transactionTypeEnum = .digital
        case "place": transactionTypeEnum = .place
        case "special": transactionTypeEnum = .special
        case "unresolved": transactionTypeEnum = .unresolved
        default: transactionTypeEnum = .unknown(transactionType)
        }
        
        return Transaction(
            id: id,
            amount: amount,
            date: date,
            name: name,
            category: category,
            accountId: accountId,
            merchantName: merchantName,
            pending: pending,
            transactionType: transactionTypeEnum
        )
    }
    
    /// Updates stored transaction with new data
    func update(from transaction: Transaction, context: ModelContext) {
        self.amount = transaction.amount
        self.date = transaction.date
        self.name = transaction.name
        self.accountId = transaction.accountId
        self.merchantName = transaction.merchantName
        self.pending = transaction.pending
        self.transactionType = transaction.transactionType.stringValue
        self.updatedAt = Date()
        
        // Update categories using the normalized approach
        updateCategories(transaction.category, context: context)
    }
    
    /// Helper method to update categories
    func updateCategories(_ newCategories: [String], context: ModelContext) {
        // Clear existing category relationships
        self.categoryTags.removeAll()
        
        // Add new categories
        for categoryName in newCategories {
            // Try to find existing category tag
            let predicate = #Predicate<CategoryTag> { $0.name == categoryName }
            let descriptor = FetchDescriptor<CategoryTag>(predicate: predicate)
            
            let categoryTag: CategoryTag
            if let existingTag = try? context.fetch(descriptor).first {
                categoryTag = existingTag
            } else {
                // Create new category tag
                categoryTag = CategoryTag(name: categoryName)
                context.insert(categoryTag)
            }
            
            self.categoryTags.append(categoryTag)
        }
    }
    
    /// Helper method to set initial categories
    func setInitialCategories(_ categories: [String], context: ModelContext) {
        updateCategories(categories, context: context)
    }
}

/// SwiftData model for persistent account storage
@Model
class StoredAccount {
    @Attribute(.unique) var id: String
    var name: String
    var type: String
    var subtype: String?
    var availableBalance: Double?
    var currentBalance: Double
    var balanceLimit: Double?
    var isoCurrencyCode: String?
    var unofficialCurrencyCode: String?
    var mask: String?
    var officialName: String?
    var createdAt: Date
    var updatedAt: Date
    
    init(
        id: String,
        name: String,
        type: String,
        subtype: String? = nil,
        availableBalance: Double? = nil,
        currentBalance: Double,
        balanceLimit: Double? = nil,
        isoCurrencyCode: String? = nil,
        unofficialCurrencyCode: String? = nil,
        mask: String? = nil,
        officialName: String? = nil
    ) {
        self.id = id
        self.name = name
        self.type = type
        self.subtype = subtype
        self.availableBalance = availableBalance
        self.currentBalance = currentBalance
        self.balanceLimit = balanceLimit
        self.isoCurrencyCode = isoCurrencyCode
        self.unofficialCurrencyCode = unofficialCurrencyCode
        self.mask = mask
        self.officialName = officialName
        self.createdAt = Date()
        self.updatedAt = Date()
    }
    
    /// Converts SwiftData model to Plaid API model
    func toAccount() -> Account {
        let accountTypeEnum: Account.AccountType
        switch type {
        case "depository": accountTypeEnum = .depository
        case "credit": accountTypeEnum = .credit
        case "loan": accountTypeEnum = .loan
        case "investment": accountTypeEnum = .investment
        case "other": accountTypeEnum = .other
        default: accountTypeEnum = .unknown(type)
        }
        
        let accountSubtypeEnum: Account.AccountSubtype?
        if let subtype = subtype {
            switch subtype {
            case "checking": accountSubtypeEnum = .checking
            case "savings": accountSubtypeEnum = .savings
            case "hsa": accountSubtypeEnum = .hsa
            case "cd": accountSubtypeEnum = .cd
            case "money market": accountSubtypeEnum = .moneyMarket
            case "paypal": accountSubtypeEnum = .paypal
            case "prepaid": accountSubtypeEnum = .prepaid
            case "cash management": accountSubtypeEnum = .cashManagement
            case "ebt": accountSubtypeEnum = .ebt
            case "credit card": accountSubtypeEnum = .creditCard
            case "payoff": accountSubtypeEnum = .payoff
            case "student": accountSubtypeEnum = .student
            case "mortgage": accountSubtypeEnum = .mortgage
            case "auto": accountSubtypeEnum = .auto
            case "commercial": accountSubtypeEnum = .commercial
            case "construction": accountSubtypeEnum = .construction
            case "consumer": accountSubtypeEnum = .consumer
            case "home equity": accountSubtypeEnum = .homeEquity
            case "line of credit": accountSubtypeEnum = .lineOfCredit
            case "loan": accountSubtypeEnum = .loan
            case "overdraft": accountSubtypeEnum = .overdraft
            case "business": accountSubtypeEnum = .business
            case "personal": accountSubtypeEnum = .personal
            default: accountSubtypeEnum = .unknown(subtype)
            }
        } else {
            accountSubtypeEnum = nil
        }
        
        let balance = AccountBalance(
            available: availableBalance,
            current: currentBalance,
            limit: balanceLimit,
            isoCurrencyCode: isoCurrencyCode,
            unofficialCurrencyCode: unofficialCurrencyCode
        )
        
        return Account(
            id: id,
            name: name,
            type: accountTypeEnum,
            subtype: accountSubtypeEnum,
            balance: balance,
            mask: mask,
            officialName: officialName
        )
    }
    
    /// Updates stored account with new data
    func update(from account: Account) {
        self.name = account.name
        self.type = account.type.stringValue
        self.subtype = account.subtype?.stringValue
        self.availableBalance = account.balance.available
        self.currentBalance = account.balance.current
        self.balanceLimit = account.balance.limit
        self.isoCurrencyCode = account.balance.isoCurrencyCode
        self.unofficialCurrencyCode = account.balance.unofficialCurrencyCode
        self.mask = account.mask
        self.officialName = account.officialName
        self.updatedAt = Date()
    }
}

// MARK: - Transaction Store

/// Main transaction store class implementing SwiftData persistence with PlaidService integration
@MainActor
class TransactionStore: ObservableObject {
    
    // MARK: - Published Properties
    
    /// Cached transactions for offline access
    @Published var cachedTransactions: [Transaction] = []
    
    /// Cached accounts for offline access
    @Published var cachedAccounts: [Account] = []
    
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
        print("✅ TransactionStore: Store initialized with provided context")
        
        // Load cached data on initialization
        Task {
            await loadCachedData()
        }
    }
    
    // MARK: - Service Integration
    
    /// Coordinator method for syncing data from external services
    func syncFromService(transactions: [Transaction], accounts: [Account]) async {
        await syncAccounts(accounts)
        await syncTransactions(transactions)
    }
    
    // MARK: - Data Synchronization
    
    /// Syncs transactions from PlaidService to local storage
    func syncTransactions(_ transactions: [Transaction]) async {
        guard isInitialized else {
            currentError = .invalidConfiguration
            return
        }
        
        isLoading = true
        defer { isLoading = false }
        
        print("🔄 TransactionStore: Syncing \(transactions.count) transactions...")
        
        do {
            // Batch lookup of existing transactions to eliminate N+1 queries
            let ids = Set(transactions.map { $0.id })
            let predicate = #Predicate<StoredTransaction> { ids.contains($0.id) }
            let existing = try modelContext.fetch(FetchDescriptor<StoredTransaction>(predicate: predicate))
            let existingById = Dictionary(uniqueKeysWithValues: existing.map { ($0.id, $0) })

            var newCount = 0, updatedCount = 0
            for t in transactions {
                if let e = existingById[t.id] { 
                    e.update(from: t, context: modelContext)
                    updatedCount += 1 
                } else {
                    let storedTransaction = StoredTransaction(
                        id: t.id, amount: t.amount, date: t.date, name: t.name,
                        category: t.category, accountId: t.accountId, merchantName: t.merchantName,
                        pending: t.pending, transactionType: t.transactionType.stringValue)
                    modelContext.insert(storedTransaction)
                    storedTransaction.setInitialCategories(t.category, context: modelContext)
                    newCount += 1
                }
            }
            
            // Improve robustness around unique constraints
            do {
                try modelContext.save()
            } catch {
                // Handle potential unique constraint conflicts gracefully
                handleError(.unknown("Failed to save: \(error.localizedDescription)"))
                return
            }
            lastSyncDate = Date()
            
            print("✅ TransactionStore: Sync completed - \(newCount) new, \(updatedCount) updated")
            
            // Refresh cached data
            await loadCachedTransactions()
            
        } catch {
            handleError(.unknown("Failed to sync transactions: \(error.localizedDescription)"))
        }
    }
    
    /// Syncs accounts from PlaidService to local storage
    func syncAccounts(_ accounts: [Account]) async {
        guard isInitialized else {
            currentError = .invalidConfiguration
            return
        }
        
        isLoading = true
        defer { isLoading = false }
        
        print("🔄 TransactionStore: Syncing \(accounts.count) accounts...")
        
        do {
            // Batch lookup of existing accounts to eliminate N+1 queries
            let ids = Set(accounts.map { $0.id })
            let predicate = #Predicate<StoredAccount> { ids.contains($0.id) }
            let existing = try modelContext.fetch(FetchDescriptor<StoredAccount>(predicate: predicate))
            let existingById = Dictionary(uniqueKeysWithValues: existing.map { ($0.id, $0) })

            var newCount = 0, updatedCount = 0
            for a in accounts {
                if let e = existingById[a.id] { 
                    e.update(from: a)
                    updatedCount += 1 
                } else {
                    modelContext.insert(StoredAccount(
                        id: a.id, name: a.name, type: a.type.stringValue,
                        subtype: a.subtype?.stringValue, availableBalance: a.balance.available,
                        currentBalance: a.balance.current, balanceLimit: a.balance.limit,
                        isoCurrencyCode: a.balance.isoCurrencyCode, 
                        unofficialCurrencyCode: a.balance.unofficialCurrencyCode,
                        mask: a.mask, officialName: a.officialName))
                    newCount += 1
                }
            }
            
            // Improve robustness around unique constraints
            do {
                try modelContext.save()
            } catch {
                // Handle potential unique constraint conflicts gracefully
                handleError(.unknown("Failed to save: \(error.localizedDescription)"))
                return
            }
            lastSyncDate = Date()
            
            print("✅ TransactionStore: Account sync completed - \(newCount) new, \(updatedCount) updated")
            
            // Refresh cached data
            await loadCachedAccounts()
            
        } catch {
            handleError(.unknown("Failed to sync accounts: \(error.localizedDescription)"))
        }
    }
    
    // MARK: - Data Retrieval
    
    /// Loads cached transactions from local storage
    func loadCachedTransactions() async {
        guard isInitialized else {
            currentError = .invalidConfiguration
            return
        }
        
        do {
            let descriptor = FetchDescriptor<StoredTransaction>(
                sortBy: [SortDescriptor(\.date, order: .reverse)]
            )
            let storedTransactions = try modelContext.fetch(descriptor)
            
            cachedTransactions = storedTransactions.map { $0.toTransaction() }
            print("📋 TransactionStore: Loaded \(cachedTransactions.count) cached transactions")
            
        } catch {
            handleError(.unknown("Failed to load cached transactions: \(error.localizedDescription)"))
        }
    }
    
    /// Loads cached accounts from local storage
    func loadCachedAccounts() async {
        guard isInitialized else {
            currentError = .invalidConfiguration
            return
        }
        
        do {
            let descriptor = FetchDescriptor<StoredAccount>(
                sortBy: [SortDescriptor(\.name, order: .forward)]
            )
            let storedAccounts = try modelContext.fetch(descriptor)
            
            cachedAccounts = storedAccounts.map { $0.toAccount() }
            print("📋 TransactionStore: Loaded \(cachedAccounts.count) cached accounts")
            
        } catch {
            handleError(.unknown("Failed to load cached accounts: \(error.localizedDescription)"))
        }
    }
    
    /// Loads all cached data
    func loadCachedData() async {
        await loadCachedTransactions()
        await loadCachedAccounts()
    }
    
    // MARK: - Data Queries
    
    /// Gets transactions for a specific account
    func getTransactions(for accountId: String) -> [Transaction] {
        return cachedTransactions.filter { $0.accountId == accountId }
    }
    
    /// Gets transactions within a date range
    func getTransactions(from startDate: Date, to endDate: Date) -> [Transaction] {
        return cachedTransactions.filter { transaction in
            transaction.date >= startDate && transaction.date <= endDate
        }
    }
    
    /// Gets transactions by category
    func getTransactions(in categories: [String]) -> [Transaction] {
        return cachedTransactions.filter { transaction in
            !Set(transaction.category).isDisjoint(with: Set(categories))
        }
    }
    
    /// Gets account by ID
    func getAccount(by id: String) -> Account? {
        return cachedAccounts.first { $0.id == id }
    }
    
    // MARK: - Data Management
    
    /// Clears all cached data
    func clearCache() async {
        guard isInitialized else {
            currentError = .invalidConfiguration
            return
        }
        
        isLoading = true
        defer { isLoading = false }
        
        do {
            // Delete all stored transactions
            let transactionDescriptor = FetchDescriptor<StoredTransaction>()
            let storedTransactions = try modelContext.fetch(transactionDescriptor)
            for transaction in storedTransactions {
                modelContext.delete(transaction)
            }
            
            // Delete all stored accounts
            let accountDescriptor = FetchDescriptor<StoredAccount>()
            let storedAccounts = try modelContext.fetch(accountDescriptor)
            for account in storedAccounts {
                modelContext.delete(account)
            }
            
            try modelContext.save()
            
            // Clear cached data
            cachedTransactions = []
            cachedAccounts = []
            lastSyncDate = nil
            
            print("🗑️ TransactionStore: Cache cleared successfully")
            
        } catch {
            handleError(.unknown("Failed to clear cache: \(error.localizedDescription)"))
        }
    }
    
    /// Gets storage statistics
    func getStorageStats() async -> (transactionCount: Int, accountCount: Int, lastSync: Date?) {
        guard isInitialized else {
            return (0, 0, nil)
        }
        
        do {
            let transactionDescriptor = FetchDescriptor<StoredTransaction>()
            let accountDescriptor = FetchDescriptor<StoredAccount>()
            
            let transactionCount = try modelContext.fetchCount(transactionDescriptor)
            let accountCount = try modelContext.fetchCount(accountDescriptor)
            
            return (transactionCount, accountCount, lastSyncDate)
            
        } catch {
            print("❌ TransactionStore: Failed to get storage stats: \(error)")
            return (0, 0, lastSyncDate)
        }
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

// MARK: - Extensions for String Conversion

extension Transaction.TransactionType {
    var stringValue: String {
        switch self {
        case .digital: return "digital"
        case .place: return "place"
        case .special: return "special"
        case .unresolved: return "unresolved"
        case .unknown(let value): return value
        }
    }
}

extension Account.AccountType {
    var stringValue: String {
        switch self {
        case .depository: return "depository"
        case .credit: return "credit"
        case .loan: return "loan"
        case .investment: return "investment"
        case .other: return "other"
        case .unknown(let value): return value
        }
    }
}

extension Account.AccountSubtype {
    var stringValue: String {
        switch self {
        case .checking: return "checking"
        case .savings: return "savings"
        case .hsa: return "hsa"
        case .cd: return "cd"
        case .moneyMarket: return "money market"
        case .paypal: return "paypal"
        case .prepaid: return "prepaid"
        case .cashManagement: return "cash management"
        case .ebt: return "ebt"
        case .creditCard: return "credit card"
        case .payoff: return "payoff"
        case .student: return "student"
        case .mortgage: return "mortgage"
        case .auto: return "auto"
        case .commercial: return "commercial"
        case .construction: return "construction"
        case .consumer: return "consumer"
        case .homeEquity: return "home equity"
        case .lineOfCredit: return "line of credit"
        case .loan: return "loan"
        case .overdraft: return "overdraft"
        case .business: return "business"
        case .personal: return "personal"
        case .unknown(let value): return value
        }
    }
}
