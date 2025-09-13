import Foundation
import SwiftData

@Model
final class Transaction: Identifiable, Hashable {
    #Index<Transaction>([\.date], [\.categoryRaw])
    enum TransactionError: Error {
        case zeroAmount
        case emptyDescription
    }

    private static let currencyFormatter: NumberFormatter = {
        let formatter = NumberFormatter()
        formatter.numberStyle = .currency
        formatter.locale = Locale.current
        return formatter
    }()

    private static let monthYearFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateFormat = "MMMM yyyy"
        return formatter
    }()
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
        return amount < 0
    }

    var transactionType: TransactionType {
        return amount >= 0 ? .debit : .credit
    }

    enum TransactionType {
        case debit
        case credit
    }

    var formattedAmount: String {
        return Self.currencyFormatter.string(from: NSDecimalNumber(decimal: amount)) ?? "$0.00"
    }

    var monthYear: String {
        return Self.monthYearFormatter.string(from: date)
    }

    func hash(into hasher: inout Hasher) {
        hasher.combine(id)
    }

    static func == (lhs: Transaction, rhs: Transaction) -> Bool {
        lhs.id == rhs.id
    }

    static func sampleTransactions() -> [Transaction] {
        let calendar = Calendar.current
        let now = Date()

        return [
            try! Transaction(
                amount: 25.50,
                description: "Coffee and pastry",
                category: .dining,
                date: calendar.date(byAdding: .day, value: -1, to: now) ?? now
            ),
            try! Transaction(
                amount: 120.00,
                description: "Weekly groceries",
                category: .groceries,
                date: calendar.date(byAdding: .day, value: -2, to: now) ?? now
            ),
            try! Transaction(
                amount: 15.99,
                description: "Movie ticket",
                category: .entertainment,
                date: calendar.date(byAdding: .day, value: -3, to: now) ?? now
            ),
            try! Transaction(
                amount: 45.00,
                description: "Gas station",
                category: .transportation,
                date: calendar.date(byAdding: .day, value: -4, to: now) ?? now
            ),
            try! Transaction(
                amount: 89.99,
                description: "New shoes",
                category: .shopping,
                date: calendar.date(byAdding: .day, value: -5, to: now) ?? now
            ),
            try! Transaction(
                amount: 150.00,
                description: "Electricity bill",
                category: .utilities,
                date: calendar.date(byAdding: .day, value: -6, to: now) ?? now
            ),
            try! Transaction(
                amount: -25.00,
                description: "Restaurant refund",
                category: .dining,
                date: calendar.date(byAdding: .day, value: -7, to: now) ?? now
            )
        ]
    }
}