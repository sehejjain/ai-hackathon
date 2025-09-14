import SwiftUI
import SwiftData
import Foundation

struct TransactionListView: View {
    @EnvironmentObject private var plaidService: PlaidService
    @EnvironmentObject private var transactionStore: TransactionStore
    @Environment(\.dismiss) private var dismiss
    @State private var isRefreshing = false
    
    var body: some View {
        NavigationView {
            VStack {
                if plaidService.transactions.isEmpty {
                    EmptyStateView()
                } else {
                    TransactionList()
                }
            }
            .navigationTitle("Transactions")
            .navigationBarTitleDisplayMode(.large)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Close") {
                        dismiss()
                    }
                }
                
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Sync to Store") {
                        Task {
                            await transactionStore.syncPlaidTransactions(plaidService.transactions)
                        }
                    }
                    .disabled(plaidService.transactions.isEmpty)
                }
            }
            .refreshable {
                await refreshTransactions()
            }
        }
    }
    
    @ViewBuilder
    private func TransactionList() -> some View {
        List {
            // Account Summary Section
            if !plaidService.accounts.isEmpty {
                Section("Accounts") {
                    ForEach(plaidService.accounts, id: \.id) { account in
                        AccountRowView(account: account)
                    }
                }
            }
            
            // Transactions Section
            Section("Recent Transactions") {
                ForEach(groupedTransactions.keys.sorted(by: >), id: \.self) { date in
                    Section(formatSectionDate(date)) {
                        ForEach(groupedTransactions[date] ?? [], id: \.id) { transaction in
                            TransactionRowView(transaction: transaction)
                        }
                    }
                }
            }
        }
        .listStyle(InsetGroupedListStyle())
    }
    
    @ViewBuilder
    private func EmptyStateView() -> some View {
        VStack(spacing: 20) {
            Image(systemName: "creditcard.trianglebadge.exclamationmark")
                .font(.system(size: 60))
                .foregroundColor(.gray)
            
            Text("No Transactions")
                .font(.title2)
                .fontWeight(.semibold)
            
            Text("Connect to Plaid to view your transaction history")
                .font(.subheadline)
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
            
            Button("Test Connection") {
                Task {
                    await plaidService.initializePlaidConnection()
                }
            }
            .buttonStyle(.borderedProminent)
        }
        .padding()
    }
    
    // MARK: - Helper Methods
    
    private var groupedTransactions: [String: [PlaidTransaction]] {
        Dictionary(grouping: plaidService.transactions) { transaction in
            formatTransactionDate(transaction.date)
        }
    }
    
    private func formatTransactionDate(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd"
        return formatter.string(from: date)
    }
    
    private func formatSectionDate(_ dateString: String) -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd"
        
        if let date = formatter.date(from: dateString) {
            let calendar = Calendar.current
            if calendar.isDateInToday(date) {
                return "Today"
            } else if calendar.isDateInYesterday(date) {
                return "Yesterday"
            } else {
                formatter.dateStyle = .medium
                return formatter.string(from: date)
            }
        }
        return dateString
    }
    
    private func refreshTransactions() async {
        isRefreshing = true
        await plaidService.refreshData()
        isRefreshing = false
    }
}

// MARK: - Account Row View

struct AccountRowView: View {
    let account: PlaidAccount
    
    var body: some View {
        HStack {
            Image(systemName: accountIcon)
                .foregroundColor(.blue)
                .frame(width: 24)
            
            VStack(alignment: .leading, spacing: 2) {
                Text(account.name)
                    .font(.headline)
                
                Text(subtypeDisplayName(account.subtype) ?? typeDisplayName(account.type))
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            
            Spacer()
            
            VStack(alignment: .trailing, spacing: 2) {
                Text(formatCurrency(account.balance.current))
                    .font(.headline)
                    .foregroundColor(account.balance.current >= 0 ? .primary : .red)
                
                if let available = account.balance.available {
                    Text("Available: \(formatCurrency(available))")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
            }
        }
        .padding(.vertical, 4)
    }
    
    private var accountIcon: String {
        switch account.type {
        case .depository:
            return "building.columns"
        case .credit:
            return "creditcard"
        case .investment:
            return "chart.line.uptrend.xyaxis"
        case .loan:
            return "house"
        case .other, .unknown:
            return "banknote"
        }
    }
    
    private func typeDisplayName(_ type: PlaidAccount.AccountType) -> String {
        switch type {
        case .depository:
            return "Depository"
        case .credit:
            return "Credit"
        case .investment:
            return "Investment"
        case .loan:
            return "Loan"
        case .other:
            return "Other"
        case .unknown(let value):
            return value.capitalized
        }
    }
    
    private func subtypeDisplayName(_ subtype: PlaidAccount.AccountSubtype?) -> String? {
        guard let subtype = subtype else { return nil }
        
        switch subtype {
        case .checking:
            return "Checking"
        case .savings:
            return "Savings"
        case .creditCard:
            return "Credit Card"
        case .hsa:
            return "HSA"
        case .cd:
            return "CD"
        case .moneyMarket:
            return "Money Market"
        case .paypal:
            return "PayPal"
        case .prepaid:
            return "Prepaid"
        case .cashManagement:
            return "Cash Management"
        case .ebt:
            return "EBT"
        case .payoff:
            return "Payoff"
        case .student:
            return "Student"
        case .mortgage:
            return "Mortgage"
        case .auto:
            return "Auto"
        case .commercial:
            return "Commercial"
        case .construction:
            return "Construction"
        case .consumer:
            return "Consumer"
        case .homeEquity:
            return "Home Equity"
        case .lineOfCredit:
            return "Line of Credit"
        case .loan:
            return "Loan"
        case .overdraft:
            return "Overdraft"
        case .business:
            return "Business"
        case .personal:
            return "Personal"
        case .unknown(let value):
            return value.capitalized
        }
    }
    
    private func formatCurrency(_ amount: Double) -> String {
        let formatter = NumberFormatter()
        formatter.numberStyle = .currency
        formatter.currencyCode = "USD"
        return formatter.string(from: NSNumber(value: amount)) ?? "$0.00"
    }
}

// MARK: - Transaction Row View

struct TransactionRowView: View {
    let transaction: PlaidTransaction
    
    var body: some View {
        HStack(spacing: 12) {
            // Category Icon
            Image(systemName: categoryIcon)
                .foregroundColor(categoryColor)
                .frame(width: 24)
            
            // Transaction Details
            VStack(alignment: .leading, spacing: 2) {
                Text(transaction.merchantName ?? transaction.name)
                    .font(.headline)
                    .lineLimit(1)
                
                HStack {
                    if let category = transaction.category?.first {
                        Text(category.capitalized)
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                    
                    Spacer()
                    
                    Text(formatDate(transaction.date))
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
            }
            
            Spacer()
            
            // Amount
            Text(formatAmount(transaction.amount))
                .font(.headline)
                .foregroundColor(transaction.amount > 0 ? .red : .green)
        }
        .padding(.vertical, 4)
    }
    
    private var categoryIcon: String {
        guard let category = transaction.category?.first?.lowercased() else {
            return "questionmark.circle"
        }
        
        switch category {
        case "food and drink", "restaurants":
            return "fork.knife"
        case "shops", "retail":
            return "bag"
        case "transportation":
            return "car"
        case "travel":
            return "airplane"
        case "entertainment":
            return "tv"
        case "healthcare":
            return "cross.case"
        case "gas stations":
            return "fuelpump"
        case "groceries":
            return "cart"
        default:
            return "dollarsign.circle"
        }
    }
    
    private var categoryColor: Color {
        guard let category = transaction.category?.first?.lowercased() else {
            return .gray
        }
        
        switch category {
        case "food and drink", "restaurants":
            return .orange
        case "shops", "retail":
            return .purple
        case "transportation":
            return .blue
        case "travel":
            return .cyan
        case "entertainment":
            return .pink
        case "healthcare":
            return .red
        case "gas stations":
            return .yellow
        case "groceries":
            return .green
        default:
            return .gray
        }
    }
    
    private func formatAmount(_ amount: Double) -> String {
        let formatter = NumberFormatter()
        formatter.numberStyle = .currency
        formatter.currencyCode = "USD"
        
        // Plaid returns positive amounts for debits (money going out)
        // and negative amounts for credits (money coming in)
        let displayAmount = abs(amount)
        let formattedAmount = formatter.string(from: NSNumber(value: displayAmount)) ?? "$0.00"
        
        return amount > 0 ? "-\(formattedAmount)" : "+\(formattedAmount)"
    }
    
    private func formatDate(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateStyle = .short
        return formatter.string(from: date)
    }
}

#Preview {
    let modelContext = try! ModelContainer(for: Transaction.self, Budget.self).mainContext
    TransactionListView()
        .environmentObject(PlaidService())
        .environmentObject(TransactionStore(modelContext: modelContext))
}
