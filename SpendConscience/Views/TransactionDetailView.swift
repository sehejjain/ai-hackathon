//
//  TransactionDetailView.swift
//  SpendConscience
//
//  Created by AI Assistant
//

import SwiftUI
import SwiftData

struct TransactionDetailView: View {
    let transactionID: UUID
    
    @EnvironmentObject var dataManager: DataManager
    @Environment(\.navigate) private var navigate
    @Environment(\.dismiss) private var dismiss
    @State private var transaction: Transaction?
    @State private var isLoading = true
    @State private var showingEditSheet = false
    @State private var showingDeleteAlert = false
    
    var body: some View {
        Group {
            if isLoading {
                ProgressView("Loading transaction...")
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else if let transaction = transaction {
                transactionDetailContent(transaction)
            } else {
                ContentUnavailableView(
                    "Transaction Not Found",
                    systemImage: "exclamationmark.triangle",
                    description: Text("The transaction you're looking for could not be found.")
                )
            }
        }
        .navigationTitle("Transaction Details")
        .navigationBarTitleDisplayMode(.large)
        .toolbar {
            ToolbarItem(placement: .navigationBarTrailing) {
                if transaction != nil {
                    Menu {
                        Button("Edit Transaction", systemImage: "pencil") {
                            showingEditSheet = true
                        }
                        
                        Button("Delete Transaction", systemImage: "trash", role: .destructive) {
                            showingDeleteAlert = true
                        }
                    } label: {
                        Image(systemName: "ellipsis.circle")
                    }
                }
            }
        }
        .onAppear {
            loadTransaction()
        }
        .onReceive(dataManager.$transactions) { _ in
            loadTransaction()
        }
        .sheet(isPresented: $showingEditSheet) {
            if let transaction = transaction {
                TransactionEditView(
                    transaction: transaction,
                    dataManager: dataManager,
                    onDismiss: {
                        showingEditSheet = false
                        loadTransaction() // Reload data after edit
                    }
                )
            }
        }
        .alert("Delete Transaction", isPresented: $showingDeleteAlert) {
            Button("Cancel", role: .cancel) { }
            Button("Delete", role: .destructive) {
                deleteTransaction()
            }
        } message: {
            Text("Are you sure you want to delete this transaction? This action cannot be undone.")
        }
    }
    
    @ViewBuilder
    private func transactionDetailContent(_ transaction: Transaction) -> some View {
        ScrollView {
            VStack(spacing: 24) {
                // Header Section
                transactionHeaderSection(transaction)
                
                // Amount Section
                amountSection(transaction)
                
                // Details Section
                detailsSection(transaction)
                
                // Category Context Section
                categoryContextSection(transaction)
                
                // Related Transactions Section
                relatedTransactionsSection(transaction)
            }
            .padding()
        }
    }
    
    @ViewBuilder
    private func transactionHeaderSection(_ transaction: Transaction) -> some View {
        VStack(spacing: 16) {
            HStack {
                Image(systemName: transaction.category.systemIcon)
                    .font(.system(size: 40))
                    .foregroundColor(transaction.category.color)
                    .frame(width: 60, height: 60)
                    .background(transaction.category.color.opacity(0.1))
                    .clipShape(Circle())
                
                VStack(alignment: .leading, spacing: 4) {
                    Text(transaction.description)
                        .font(.title2)
                        .fontWeight(.bold)
                        .lineLimit(2)
                    
                    Text(transaction.category.displayName)
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                }
                
                Spacer()
                
                VStack(alignment: .trailing, spacing: 4) {
                    Text(transaction.amount < 0 ? "Expense" : "Income")
                        .font(.caption)
                        .fontWeight(.semibold)
                        .foregroundColor(transaction.amount < 0 ? .red : .green)
                        .padding(.horizontal, 8)
                        .padding(.vertical, 4)
                        .background(
                            (transaction.amount < 0 ? Color.red : Color.green).opacity(0.1)
                        )
                        .clipShape(Capsule())
                }
            }
        }
        .padding()
        .background(Color(.systemGray6))
        .clipShape(RoundedRectangle(cornerRadius: 16))
    }
    
    @ViewBuilder
    private func amountSection(_ transaction: Transaction) -> some View {
        VStack(spacing: 16) {
            Text("Amount")
                .font(.headline)
                .frame(maxWidth: .infinity, alignment: .leading)
            
            HStack {
                Spacer()
                
                VStack(spacing: 8) {
                    Text(abs(transaction.amount).formatted(.currency(code: "USD")))
                        .font(.system(size: 48, weight: .bold))
                        .foregroundColor(transaction.amount < 0 ? .red : .green)
                    
                    Text(transaction.amount < 0 ? "Debit" : "Credit")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                }
                
                Spacer()
            }
        }
        .padding()
        .background(Color(.systemGray6))
        .clipShape(RoundedRectangle(cornerRadius: 16))
    }
    
    @ViewBuilder
    private func detailsSection(_ transaction: Transaction) -> some View {
        VStack(spacing: 16) {
            Text("Transaction Details")
                .font(.headline)
                .frame(maxWidth: .infinity, alignment: .leading)
            
            VStack(spacing: 12) {
                detailRow(
                    title: "Date",
                    value: transaction.date.formatted(date: .complete, time: .shortened),
                    icon: "calendar"
                )
                
                detailRow(
                    title: "Category",
                    value: transaction.category.displayName,
                    icon: "tag"
                )
                
                detailRow(
                    title: "Account ID",
                    value: transaction.accountId,
                    icon: "creditcard"
                )
                
                if !transaction.description.isEmpty {
                    detailRow(
                        title: "Description",
                        value: transaction.description,
                        icon: "text.alignleft"
                    )
                }
                
                detailRow(
                    title: "Transaction ID",
                    value: String(transaction.id.uuidString.prefix(8)) + "...",
                    icon: "number"
                )
            }
        }
        .padding()
        .background(Color(.systemGray6))
        .clipShape(RoundedRectangle(cornerRadius: 16))
    }
    
    @ViewBuilder
    private func detailRow(title: String, value: String, icon: String) -> some View {
        HStack(spacing: 12) {
            Image(systemName: icon)
                .font(.title3)
                .foregroundColor(.blue)
                .frame(width: 24)
            
            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(.caption)
                    .foregroundColor(.secondary)
                
                Text(value)
                    .font(.subheadline)
                    .fontWeight(.medium)
            }
            
            Spacer()
        }
    }
    
    @ViewBuilder
    private func categoryContextSection(_ transaction: Transaction) -> some View {
        if let budget = dataManager.getBudgetForCategory(transaction.category) {
            VStack(spacing: 16) {
                HStack {
                    Text("Budget Context")
                        .font(.headline)
                    
                    Spacer()
                    
                    Button("View Budget") {
                        navigate(.budgetDetail(budget))
                    }
                    .font(.subheadline)
                    .foregroundColor(.blue)
                }
                
                VStack(spacing: 12) {
                    HStack {
                        Text("Monthly Budget")
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                        
                        Spacer()
                        
                        Text(budget.monthlyLimit.formatted(.currency(code: "USD")))
                            .font(.subheadline)
                            .fontWeight(.semibold)
                    }
                    
                    HStack {
                        Text("Current Spent")
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                        
                        Spacer()
                        
                        Text(budget.currentSpent.formatted(.currency(code: "USD")))
                            .font(.subheadline)
                            .fontWeight(.semibold)
                            .foregroundColor(budget.isOverBudget ? .red : .primary)
                    }
                    
                    HStack {
                        Text("Budget Utilization")
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                        
                        Spacer()
                        
                        Text("\(Int(budget.utilizationPercentage))%")
                            .font(.subheadline)
                            .fontWeight(.semibold)
                            .foregroundColor(budget.isOverBudget ? .red : .green)
                    }
                }
            }
            .padding()
            .background(Color(.systemGray6))
            .clipShape(RoundedRectangle(cornerRadius: 16))
        }
    }
    
    @ViewBuilder
    private func relatedTransactionsSection(_ transaction: Transaction) -> some View {
        VStack(spacing: 16) {
            HStack {
                Text("Related Transactions")
                    .font(.headline)
                
                Spacer()
                
                Button("View All in Category") {
                    navigate(.transactionHistory)
                }
                .font(.subheadline)
                .foregroundColor(.blue)
            }
            
            let relatedTransactions = dataManager.getTransactionsForCategory(transaction.category, limit: 3)
                .filter { $0.id != transaction.id }
            
            if relatedTransactions.isEmpty {
                Text("No other transactions in this category")
                    .font(.subheadline)
                    .foregroundColor(.secondary)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 20)
            } else {
                LazyVStack(spacing: 8) {
                    ForEach(relatedTransactions) { relatedTransaction in
                        RelatedTransactionRowView(transaction: relatedTransaction)
                            .onTapGesture {
                                navigate(.transactionDetail(relatedTransaction))
                            }
                    }
                }
            }
        }
        .padding()
        .background(Color(.systemGray6))
        .clipShape(RoundedRectangle(cornerRadius: 16))
    }
    
    // MARK: - Private Methods
    
    private func loadTransaction() {
        isLoading = true
        transaction = dataManager.getTransactionByID(transactionID)
        isLoading = false
    }
    
    private func deleteTransaction() {
        guard let transaction = transaction else { return }
        Task {
            let success = await dataManager.deleteTransaction(transaction)
            if success {
                dismiss()
            }
        }
    }
}

// MARK: - Related Transaction Row View

struct RelatedTransactionRowView: View {
    let transaction: Transaction
    
    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: transaction.category.systemIcon)
                .font(.title3)
                .foregroundColor(transaction.category.color)
                .frame(width: 28, height: 28)
                .background(transaction.category.color.opacity(0.1))
                .clipShape(Circle())
            
            VStack(alignment: .leading, spacing: 2) {
                Text(transaction.description)
                    .font(.subheadline)
                    .fontWeight(.medium)
                    .lineLimit(1)
                
                Text(transaction.date.formatted(date: .abbreviated, time: .omitted))
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            
            Spacer()
            
            Text(abs(transaction.amount).formatted(.currency(code: "USD")))
                .font(.subheadline)
                .fontWeight(.semibold)
                .foregroundColor(transaction.amount < 0 ? .red : .green)
        }
        .padding(.vertical, 6)
        .padding(.horizontal, 12)
        .background(Color(.systemBackground))
        .clipShape(RoundedRectangle(cornerRadius: 8))
    }
}

#Preview {
    NavigationView {
        TransactionDetailView(transactionID: UUID())
            .environmentObject(DataManager(modelContext: ModelContext(try! ModelContainer(for: Budget.self, Transaction.self))))
    }
}
