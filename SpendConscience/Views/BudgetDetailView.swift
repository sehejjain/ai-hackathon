//
//  BudgetDetailView.swift
//  SpendConscience
//
//  Created by AI Assistant
//

import SwiftUI
import SwiftData

struct BudgetDetailView: View {
    let budgetID: UUID
    
    @EnvironmentObject var dataManager: DataManager
    @Environment(\.navigate) private var navigate
    @Environment(\.dismiss) private var dismiss
    @State private var budget: Budget?
    @State private var isLoading = true
    @State private var showingEditSheet = false
    @State private var showingDeleteAlert = false
    
    var body: some View {
        Group {
            if isLoading {
                ProgressView("Loading budget...")
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else if let budget = budget {
                budgetDetailContent(budget)
            } else {
                ContentUnavailableView(
                    "Budget Not Found",
                    systemImage: "exclamationmark.triangle",
                    description: Text("The budget you're looking for could not be found.")
                )
            }
        }
        .navigationTitle(budget?.category.displayName ?? "Budget Details")
        .navigationBarTitleDisplayMode(.large)
        .toolbar {
            ToolbarItem(placement: .navigationBarTrailing) {
                if budget != nil {
                    Menu {
                        Button("Edit Budget", systemImage: "pencil") {
                            showingEditSheet = true
                        }
                        
                        Button("Delete Budget", systemImage: "trash", role: .destructive) {
                            showingDeleteAlert = true
                        }
                    } label: {
                        Image(systemName: "ellipsis.circle")
                    }
                }
            }
        }
        .onAppear {
            loadBudget()
        }
        .sheet(isPresented: $showingEditSheet) {
            if let budget = budget {
                // TODO: Create BudgetEditView
                Text("Edit Budget View")
                    .navigationTitle("Edit Budget")
            }
        }
        .alert("Delete Budget", isPresented: $showingDeleteAlert) {
            Button("Cancel", role: .cancel) { }
            Button("Delete", role: .destructive) {
                deleteBudget()
            }
        } message: {
            Text("Are you sure you want to delete this budget? This action cannot be undone.")
        }
    }
    
    @ViewBuilder
    private func budgetDetailContent(_ budget: Budget) -> some View {
        ScrollView {
            VStack(spacing: 24) {
                // Header Section
                budgetHeaderSection(budget)
                
                // Progress Section
                budgetProgressSection(budget)
                
                // Financial Summary
                financialSummarySection(budget)
                
                // Transaction History
                transactionHistorySection(budget)
                
                // Trends Section
                trendsSection(budget)
            }
            .padding()
        }
    }
    
    @ViewBuilder
    private func budgetHeaderSection(_ budget: Budget) -> some View {
        VStack(spacing: 16) {
            HStack {
                Image(systemName: budget.category.systemIcon)
                    .font(.system(size: 40))
                    .foregroundColor(budget.category.color)
                    .frame(width: 60, height: 60)
                    .background(budget.category.color.opacity(0.1))
                    .clipShape(Circle())
                
                VStack(alignment: .leading, spacing: 4) {
                    Text(budget.category.displayName)
                        .font(.title2)
                        .fontWeight(.bold)
                    
                    Text("Monthly Budget")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                }
                
                Spacer()
                
                VStack(alignment: .trailing, spacing: 4) {
                    Text(budget.isOverBudget ? "Over Budget" : "On Track")
                        .font(.caption)
                        .fontWeight(.semibold)
                        .foregroundColor(budget.isOverBudget ? .red : .green)
                        .padding(.horizontal, 8)
                        .padding(.vertical, 4)
                        .background(
                            (budget.isOverBudget ? Color.red : Color.green).opacity(0.1)
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
    private func budgetProgressSection(_ budget: Budget) -> some View {
        VStack(spacing: 16) {
            Text("Budget Progress")
                .font(.headline)
                .frame(maxWidth: .infinity, alignment: .leading)
            
            ZStack {
                Circle()
                    .stroke(Color(.systemGray5), lineWidth: 12)
                    .frame(width: 200, height: 200)
                
                Circle()
                    .trim(from: 0, to: min(budget.utilizationPercentage / 100, 1.0))
                    .stroke(
                        budget.isOverBudget ? .red : budget.category.color,
                        style: StrokeStyle(lineWidth: 12, lineCap: .round)
                    )
                    .frame(width: 200, height: 200)
                    .rotationEffect(.degrees(-90))
                    .animation(.easeInOut(duration: 1.0), value: budget.utilizationPercentage)
                
                VStack(spacing: 4) {
                    Text("\(Int(budget.utilizationPercentage))%")
                        .font(.system(size: 36, weight: .bold))
                        .foregroundColor(budget.isOverBudget ? .red : .primary)
                    
                    Text("Used")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                }
            }
        }
        .padding()
        .background(Color(.systemGray6))
        .clipShape(RoundedRectangle(cornerRadius: 16))
    }
    
    @ViewBuilder
    private func financialSummarySection(_ budget: Budget) -> some View {
        VStack(spacing: 16) {
            Text("Financial Summary")
                .font(.headline)
                .frame(maxWidth: .infinity, alignment: .leading)
            
            VStack(spacing: 12) {
                financialRow(
                    title: "Monthly Limit",
                    amount: NSDecimalNumber(decimal: budget.monthlyLimit).doubleValue,
                    color: .blue
                )
                
                financialRow(
                    title: "Current Spent",
                    amount: NSDecimalNumber(decimal: budget.currentSpent).doubleValue,
                    color: budget.isOverBudget ? .red : .orange
                )
                
                financialRow(
                    title: budget.isOverBudget ? "Over Budget" : "Remaining",
                    amount: budget.isOverBudget ? NSDecimalNumber(decimal: budget.currentSpent - budget.monthlyLimit).doubleValue : NSDecimalNumber(decimal: budget.remainingAmount).doubleValue,
                    color: budget.isOverBudget ? .red : .green
                )
            }
        }
        .padding()
        .background(Color(.systemGray6))
        .clipShape(RoundedRectangle(cornerRadius: 16))
    }
    
    @ViewBuilder
    private func financialRow(title: String, amount: Double, color: Color) -> some View {
        HStack {
            Text(title)
                .font(.subheadline)
                .foregroundColor(.secondary)
            
            Spacer()
            
            Text(amount.formatted(.currency(code: "USD")))
                .font(.subheadline)
                .fontWeight(.semibold)
                .foregroundColor(color)
        }
    }
    
    @ViewBuilder
    private func transactionHistorySection(_ budget: Budget) -> some View {
        VStack(spacing: 16) {
            HStack {
                Text("Recent Transactions")
                    .font(.headline)
                
                Spacer()
                
                Button("View All") {
                    navigate(.transactionHistory)
                }
                .font(.subheadline)
                .foregroundColor(.blue)
            }
            
            let recentTransactions = dataManager.getTransactionsForCategory(budget.category, limit: 5)
            
            if recentTransactions.isEmpty {
                Text("No transactions yet")
                    .font(.subheadline)
                    .foregroundColor(.secondary)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 20)
            } else {
                LazyVStack(spacing: 8) {
                    ForEach(recentTransactions) { transaction in
                        BudgetTransactionRowView(transaction: transaction)
                            .onTapGesture {
                                navigate(.transactionDetail(transaction))
                            }
                    }
                }
            }
        }
        .padding()
        .background(Color(.systemGray6))
        .clipShape(RoundedRectangle(cornerRadius: 16))
    }
    
    @ViewBuilder
    private func trendsSection(_ budget: Budget) -> some View {
        VStack(spacing: 16) {
            Text("Spending Trends")
                .font(.headline)
                .frame(maxWidth: .infinity, alignment: .leading)
            
            HStack(spacing: 16) {
                trendCard(
                    title: "This Week",
                    amount: NSDecimalNumber(decimal: dataManager.getWeeklySpendingForCategory(budget.category)).doubleValue,
                    comparison: "vs last week",
                    isPositive: false
                )
                
                trendCard(
                    title: "Average Daily",
                    amount: NSDecimalNumber(decimal: budget.currentSpent).doubleValue / 30, // Simplified calculation
                    comparison: "this month",
                    isPositive: true
                )
            }
        }
        .padding()
        .background(Color(.systemGray6))
        .clipShape(RoundedRectangle(cornerRadius: 16))
    }
    
    @ViewBuilder
    private func trendCard(title: String, amount: Double, comparison: String, isPositive: Bool) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(title)
                .font(.caption)
                .foregroundColor(.secondary)
            
            Text(amount.formatted(.currency(code: "USD")))
                .font(.headline)
                .fontWeight(.semibold)
            
            Text(comparison)
                .font(.caption2)
                .foregroundColor(.secondary)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding()
        .background(Color(.systemBackground))
        .clipShape(RoundedRectangle(cornerRadius: 12))
    }
    
    // MARK: - Private Methods
    
    private func loadBudget() {
        isLoading = true
        budget = dataManager.getBudgetByID(budgetID)
        isLoading = false
    }
    
    private func deleteBudget() {
        guard let budget = budget else { return }
        Task {
            let success = await dataManager.deleteBudget(budget)
            if success {
                dismiss()
            }
        }
    }
}

// MARK: - Budget Transaction Row View

struct BudgetTransactionRowView: View {
    let transaction: Transaction
    
    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: transaction.category.systemIcon)
                .font(.title3)
                .foregroundColor(transaction.category.color)
                .frame(width: 32, height: 32)
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
            
            Text(transaction.amount.formatted(.currency(code: "USD")))
                .font(.subheadline)
                .fontWeight(.semibold)
                .foregroundColor(transaction.amount < 0 ? .red : .green)
        }
        .padding(.vertical, 8)
        .padding(.horizontal, 12)
        .background(Color(.systemBackground))
        .clipShape(RoundedRectangle(cornerRadius: 8))
    }
}

#Preview {
    NavigationView {
        BudgetDetailView(budgetID: UUID())
            .environmentObject(DataManager(modelContext: ModelContext(try! ModelContainer(for: Budget.self, Transaction.self))))
    }
}
