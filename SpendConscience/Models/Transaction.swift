import Foundation
import SwiftData

@Model
final class Transaction: Identifiable, Hashable {
    #Index<Transaction>([\.date], [\.categoryRaw])
    enum TransactionError: Error {
        case zeroAmount
        case emptyDescription
    }

    @Attribute(.unique) var id: UUID
    var amount: Decimal
    var transactionDescription: String
    private var categoryRaw: String
    var date: Date
    var accountId: String

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

    init(
        id: UUID = UUID(),
        amount: Decimal,
        description: String,
        category: TransactionCategory,
        date: Date = Date(),
        accountId: String = "default"
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
    }


    var isRecent: Bool {
        Calendar.current.dateInterval(of: .weekOfYear, for: Date())?.contains(date) ?? false
    }

    var isCredit: Bool {
        return transactionType == .credit
    }

    var transactionType: TransactionType {
        return amount < 0 ? .debit : .credit
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

#if DEBUG
    static func sampleTransactions() -> [Transaction] {
        let calendar = Calendar.current
        let now = Date()

        let transactionConfigs: [(Decimal, String, TransactionCategory, Int)] = [
            (25.50, "Coffee and pastry", .dining, -1),
            (120.00, "Weekly groceries", .groceries, -2),
            (15.99, "Movie ticket", .entertainment, -3),
            (45.00, "Gas station", .transportation, -4),
            (89.99, "New shoes", .shopping, -5),
            (150.00, "Electricity bill", .utilities, -6),
            (-25.00, "Restaurant refund", .dining, -7)
        ]

        return transactionConfigs.compactMap { amount, description, category, dayOffset in
            let date = calendar.date(byAdding: .day, value: dayOffset, to: now) ?? now
            do {
                return try Transaction(amount: amount, description: description, category: category, date: date)
            } catch {
                print("Failed to create sample transaction: \(error)")
                return nil
            }
        }
    }
#endif
}