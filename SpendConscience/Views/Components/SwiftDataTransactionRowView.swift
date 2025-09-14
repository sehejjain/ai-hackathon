import SwiftUI

struct SwiftDataTransactionRowView: View {
    let transaction: Transaction

    var body: some View {
        HStack(spacing: 12) {
            categoryIcon

            transactionDetails

            Spacer()

            amountDisplay
        }
        .padding(.vertical, 4)
    }

    private var categoryIcon: some View {
        ZStack {
            Circle()
                .fill(transaction.category.color.opacity(0.2))
                .frame(width: 40, height: 40)

            Image(systemName: transaction.category.systemIcon)
                .foregroundColor(transaction.category.color)
                .font(.system(size: 16, weight: .medium))
        }
    }

    private var transactionDetails: some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(transaction.description)
                .font(.headline)
                .lineLimit(1)

            HStack(spacing: 8) {
                Text(transaction.category.displayName)
                    .font(.caption)
                    .foregroundColor(.secondary)

                Text("•")
                    .font(.caption)
                    .foregroundColor(.secondary)

                Text(formattedDate)
                    .font(.caption)
                    .foregroundColor(.secondary)

                if transaction.transactionType == .credit {
                    Spacer()

                    Text("CREDIT")
                        .font(.caption2)
                        .fontWeight(.medium)
                        .foregroundColor(.white)
                        .padding(.horizontal, 6)
                        .padding(.vertical, 2)
                        .background(Color.green)
                        .cornerRadius(4)
                }
            }
        }
    }

    private var amountDisplay: some View {
        VStack(alignment: .trailing, spacing: 2) {
            Text(transaction.formattedAmount)
                .font(.headline)
                .fontWeight(.semibold)
                .foregroundColor(transaction.transactionType == .debit ? .primary : .green)

            if transaction.isRecent {
                Text("Recent")
                    .font(.caption2)
                    .fontWeight(.medium)
                    .foregroundColor(.white)
                    .padding(.horizontal, 6)
                    .padding(.vertical, 2)
                    .background(Color.blue)
                    .cornerRadius(4)
            }
        }
    }

    private var formattedDate: String {
        let formatter = DateFormatter()
        let calendar = Calendar.current

        if calendar.isDateInToday(transaction.date) {
            formatter.timeStyle = .short
            return "Today, \(formatter.string(from: transaction.date))"
        } else if calendar.isDateInYesterday(transaction.date) {
            formatter.timeStyle = .short
            return "Yesterday, \(formatter.string(from: transaction.date))"
        } else if calendar.dateInterval(of: .weekOfYear, for: Date())?.contains(transaction.date) == true {
            formatter.dateFormat = "EEEE"
            return formatter.string(from: transaction.date)
        } else {
            formatter.dateStyle = .short
            return formatter.string(from: transaction.date)
        }
    }
}

#if DEBUG
#Preview("Debit Transaction") {
    let sampleTransaction = try! Transaction(
        amount: 25.50,
        description: "Coffee and Pastry",
        category: .dining,
        date: Date()
    )

    List {
        SwiftDataTransactionRowView(transaction: sampleTransaction)
    }
    .listStyle(InsetGroupedListStyle())
}

#Preview("Credit Transaction") {
    let sampleTransaction = try! Transaction(
        amount: -50.00,
        description: "Refund for cancelled order",
        category: .shopping,
        date: Calendar.current.date(byAdding: .day, value: -2, to: Date()) ?? Date()
    )

    List {
        SwiftDataTransactionRowView(transaction: sampleTransaction)
    }
    .listStyle(InsetGroupedListStyle())
}

#Preview("Multiple Transactions") {
    let transactions = Transaction.sampleTransactions()

    List {
        ForEach(transactions, id: \.id) { transaction in
            SwiftDataTransactionRowView(transaction: transaction)
        }
    }
    .listStyle(InsetGroupedListStyle())
}
#endif