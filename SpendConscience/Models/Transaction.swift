import Foundation
import SwiftData

@Model
final class Transaction: Identifiable, Hashable {
    #Index<Transaction>([\.date], [\.categoryRaw])
    enum TransactionError: Error {
        case zeroAmount
        case emptyDescription
    }

    enum TransactionDataSource: String, CaseIterable {
        case local = "local"
        case backend = "backend"
        case hybrid = "hybrid"
    }

    @Attribute(.unique) var id: UUID
    var amount: Decimal
    var transactionDescription: String
    private var categoryRaw: String
    var date: Date
    var accountId: String
    var dataSourceRaw: String?
    var backendSyncDate: Date?
    var backendId: String?
    var merchantName: String?

    @Relationship var budget: Budget?

    var category: TransactionCategory {
        get {
            TransactionCategory(rawValue: categoryRaw) ?? .other
        }
        set {
            categoryRaw = newValue.rawValue
        }
    }

    var description: String {
        get {
            transactionDescription
        }
        set {
            transactionDescription = newValue
        }
    }

    var dataSource: TransactionDataSource? {
        get {
            guard let dataSourceRaw = dataSourceRaw else { return nil }
            return TransactionDataSource(rawValue: dataSourceRaw)
        }
        set {
            dataSourceRaw = newValue?.rawValue
        }
    }

    var isFromBackend: Bool {
        return dataSource == .backend || dataSource == .hybrid
    }

    var isFromLocal: Bool {
        return dataSource == .local || dataSource == .hybrid
    }

    init(
        id: UUID = UUID(),
        amount: Decimal,
        description: String,
        category: TransactionCategory,
        date: Date = Date(),
        accountId: String = "default",
        dataSource: TransactionDataSource? = .local
    ) throws {
        guard amount != 0 else {
            throw TransactionError.zeroAmount
        }
        guard !description.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            throw TransactionError.emptyDescription
        }

        self.id = id
        self.amount = amount
        self.transactionDescription = description
        self.categoryRaw = category.rawValue
        self.date = date
        self.accountId = accountId
        self.dataSourceRaw = dataSource?.rawValue
        self.backendSyncDate = dataSource == .backend ? Date() : nil
    }

    convenience init(from backendTransaction: BackendTransaction) throws {
        try self.init(
            id: UUID(uuidString: backendTransaction.id) ?? UUID(),
            amount: Decimal(backendTransaction.amount),
            description: backendTransaction.description,
            category: TransactionCategory(rawValue: backendTransaction.category) ?? .other,
            date: backendTransaction.date,
            accountId: backendTransaction.accountId,
            dataSource: .backend
        )
        self.backendId = backendTransaction.id
        self.merchantName = backendTransaction.merchantName
        self.backendSyncDate = Date()
    }


    var isRecent: Bool {
        Calendar.current.dateInterval(of: .weekOfYear, for: Date())?.contains(date) ?? false
    }

    var isCredit: Bool {
        return transactionType == .credit
    }

    var transactionType: TransactionType {
        return amount >= 0 ? .debit : .credit
    }

    enum TransactionType {
        case debit
        case credit
    }

    var formattedAmount: String {
        return amount.formatted(.currency(code: Locale.current.currency?.identifier ?? "USD"))
    }

    var monthYear: String {
        return date.formatted(.dateTime.month(.wide).year())
    }

    func hash(into hasher: inout Hasher) {
        hasher.combine(id)
    }

    static func == (lhs: Transaction, rhs: Transaction) -> Bool {
        lhs.id == rhs.id
    }

    func mergeWithBackendData(_ backendTransaction: BackendTransaction) {
        // Update transaction with backend data while preserving local modifications
        let backendAmount = Decimal(backendTransaction.amount)
        if self.amount != backendAmount {
            self.amount = backendAmount
        }
        if self.description != backendTransaction.description {
            self.description = backendTransaction.description
        }
        let backendCategory = TransactionCategory(rawValue: backendTransaction.category) ?? .other
        if self.category != backendCategory {
            self.category = backendCategory
        }
        if self.date != backendTransaction.date {
            self.date = backendTransaction.date
        }
        
        // Update data source to hybrid and sync date
        self.dataSource = .hybrid
        self.backendSyncDate = Date()
    }

    func validateDataIntegrity() -> Bool {
        // Ensure backend-converted transactions maintain data integrity
        guard amount != 0 else { return false }
        guard !description.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else { return false }
        guard TransactionCategory.allCases.contains(category) else { return false }
        return true
    }

#if DEBUG
    static func sampleTransactions() -> [Transaction] {
        let calendar = Calendar.current
        let now = Date()

        let transactionConfigs: [(Decimal, String, TransactionCategory, Int, TransactionDataSource)] = [
            (25.50, "Coffee and pastry", .dining, -1, .local),
            (120.00, "Weekly groceries", .groceries, -2, .backend),
            (15.99, "Movie ticket", .entertainment, -3, .local),
            (45.00, "Gas station", .transportation, -4, .backend),
            (89.99, "New shoes", .shopping, -5, .hybrid),
            (150.00, "Electricity bill", .utilities, -6, .local),
            (-25.00, "Restaurant refund", .dining, -7, .backend)
        ]

        return transactionConfigs.compactMap { amount, description, category, dayOffset, dataSource in
            let date = calendar.date(byAdding: .day, value: dayOffset, to: now) ?? now
            do {
                return try Transaction(amount: amount, description: description, category: category, date: date, dataSource: dataSource)
            } catch {
                print("Failed to create sample transaction: \(error)")
                return nil
            }
        }
    }
#endif
}
