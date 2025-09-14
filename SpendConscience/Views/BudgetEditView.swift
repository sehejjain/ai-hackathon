//
//  BudgetEditView.swift
//  SpendConscience
//
//  Created by AI Assistant
//

import SwiftUI
import SwiftData

struct BudgetEditView: View {
    let budget: Budget
    @EnvironmentObject var dataManager: DataManager
    @Environment(\.dismiss) private var dismiss
    
    @State private var selectedCategory: TransactionCategory
    @State private var monthlyLimitText: String
    @State private var alertThreshold: Double
    @State private var showingError = false
    @State private var errorMessage = ""
    @State private var isSaving = false
    
    // Static currency formatter for consistent formatting
    private static let currencyFormatter: NumberFormatter = {
        let formatter = NumberFormatter()
        formatter.numberStyle = .currency
        formatter.maximumFractionDigits = 2
        return formatter
    }()
    
    init(budget: Budget) {
        self.budget = budget
        self._selectedCategory = State(initialValue: budget.category)
        self._monthlyLimitText = State(initialValue: Self.currencyFormatter.string(from: NSDecimalNumber(decimal: budget.monthlyLimit)) ?? "")
        self._alertThreshold = State(initialValue: budget.alertThreshold)
    }
    
    var body: some View {
        NavigationView {
            Form {
                Section("Budget Category") {
                    Picker("Category", selection: $selectedCategory) {
                        ForEach(TransactionCategory.allCases, id: \.self) { category in
                            HStack {
                                Image(systemName: category.systemIcon)
                                    .foregroundColor(category.color)
                                Text(category.displayName)
                            }
                            .tag(category)
                        }
                    }
                    .pickerStyle(.menu)
                    .accessibilityLabel("Budget category")
                    .accessibilityValue(selectedCategory.displayName)
                }
                
                Section("Monthly Limit") {
                    TextField("Amount", text: $monthlyLimitText)
                        .keyboardType(.decimalPad)
                        .textFieldStyle(.roundedBorder)
                        .accessibilityLabel("Monthly budget limit")
                        .accessibilityHint("Enter the maximum amount to spend in this category per month")
                    
                    Text("Current limit: \(formatCurrency(budget.monthlyLimit))")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                
                Section("Alert Settings") {
                    VStack(alignment: .leading, spacing: 8) {
                        HStack {
                            Text("Alert at")
                            Spacer()
                            Text("\(Int(alertThreshold * 100))% of limit")
                                .foregroundColor(.secondary)
                        }
                        
                        Slider(value: $alertThreshold, in: 0.5...1.0, step: 0.05) {
                            Text("Alert Threshold")
                        } minimumValueLabel: {
                            Text("50%")
                                .font(.caption)
                        } maximumValueLabel: {
                            Text("100%")
                                .font(.caption)
                        }
                        .tint(selectedCategory.color)
                        
                        Text("You'll receive an alert when spending reaches \(Int(alertThreshold * 100))% of your monthly limit.")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                }
                
                Section("Budget Information") {
                    budgetInfoRows
                }
            }
            .navigationTitle("Edit Budget")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Cancel") {
                        dismiss()
                    }
                }
                
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Save") {
                        saveBudget()
                    }
                    .disabled(isSaving || !isValidInput)
                    .foregroundColor(isValidInput ? .accentColor : .secondary)
                }
            }
            .alert("Error", isPresented: $showingError) {
                Button("OK") { }
            } message: {
                Text(errorMessage)
            }
            .disabled(isSaving)
            .overlay {
                if isSaving {
                    ProgressView("Saving...")
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                        .background(Color.black.opacity(0.3))
                }
            }
        }
    }
    
    // MARK: - Budget Information Rows
    
    private var budgetInfoRows: some View {
        Group {
            HStack {
                Label("Current Spent", systemImage: "creditcard")
                Spacer()
                Text(formatCurrency(budget.currentSpent))
                    .foregroundColor(budget.isOverBudget ? .red : .primary)
            }
            
            HStack {
                Label("Remaining", systemImage: "banknote")
                Spacer()
                Text(formatCurrency(budget.remainingAmount))
                    .foregroundColor(budget.isOverBudget ? .red : .green)
            }
            
            HStack {
                Label("Utilization", systemImage: "chart.pie")
                Spacer()
                Text("\(Int(budget.utilizationPercentage * 100))%")
                    .foregroundColor(budget.status == .danger ? .red : budget.status == .warning ? .orange : .green)
            }
            
            HStack {
                Label("Status", systemImage: statusIcon)
                Spacer()
                Text(statusText)
                    .foregroundColor(statusColor)
            }
            
            if budget.isFromBackend {
                HStack {
                    Label("Data Source", systemImage: "cloud")
                    Spacer()
                    Text("AI Enhanced")
                        .foregroundColor(.blue)
                }
            }
        }
    }
    
    // MARK: - Computed Properties
    
    private var isValidInput: Bool {
        guard let amount = parseMoneyAmount(monthlyLimitText), amount > 0 else {
            return false
        }
        return true
    }
    
    private var statusIcon: String {
        switch budget.status {
        case .safe:
            return "checkmark.circle.fill"
        case .warning:
            return "exclamationmark.triangle.fill"
        case .danger:
            return "x.circle.fill"
        }
    }
    
    private var statusText: String {
        switch budget.status {
        case .safe:
            return "On Track"
        case .warning:
            return "Near Limit"
        case .danger:
            return "Over Budget"
        }
    }
    
    private var statusColor: Color {
        switch budget.status {
        case .safe:
            return .green
        case .warning:
            return .orange
        case .danger:
            return .red
        }
    }
    
    // MARK: - Helper Methods
    
    private func formatCurrency(_ amount: Decimal) -> String {
        return Self.currencyFormatter.string(from: NSDecimalNumber(decimal: amount)) ?? "$0.00"
    }
    
    private func parseMoneyAmount(_ text: String) -> Decimal? {
        // Remove currency symbols and formatting
        let cleanText = text.replacingOccurrences(of: "$", with: "")
            .replacingOccurrences(of: ",", with: "")
            .trimmingCharacters(in: .whitespacesAndNewlines)
        
        return Decimal(string: cleanText)
    }
    
    private func saveBudget() {
        guard let newLimit = parseMoneyAmount(monthlyLimitText), newLimit > 0 else {
            errorMessage = "Please enter a valid amount greater than $0."
            showingError = true
            return
        }
        
        // Check if category is already in use by another budget
        let existingBudgets = dataManager.budgets.filter { $0.id != budget.id }
        if existingBudgets.contains(where: { $0.category == selectedCategory }) {
            errorMessage = "A budget for \(selectedCategory.displayName) already exists. Please choose a different category."
            showingError = true
            return
        }
        
        isSaving = true
        
        Task {
            // Update the budget properties
            budget.category = selectedCategory
            budget.monthlyLimit = newLimit
            budget.alertThreshold = alertThreshold
            
            // Save through DataManager
            let success = await dataManager.updateBudget(budget)
            
            await MainActor.run {
                isSaving = false
                if success {
                    dismiss()
                } else {
                    errorMessage = "Failed to save budget. Please try again."
                    showingError = true
                }
            }
        }
    }
}

// MARK: - Preview

#Preview {
    let sampleBudget = try! Budget(
        category: .dining,
        monthlyLimit: Decimal(500),
        currentSpent: Decimal(275),
        alertThreshold: 0.8
    )
    
    BudgetEditView(budget: sampleBudget)
        .environmentObject(DataManager.preview())
}

#Preview("Over Budget") {
    let overBudget = try! Budget(
        category: .entertainment,
        monthlyLimit: Decimal(200),
        currentSpent: Decimal(250),
        alertThreshold: 0.75
    )
    
    BudgetEditView(budget: overBudget)
        .environmentObject(DataManager.preview())
}