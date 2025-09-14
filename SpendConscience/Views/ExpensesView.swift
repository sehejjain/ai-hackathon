//
//  ExpensesView.swift
//  SpendConscience
//
//  Created by AI Assistant on 9/14/25.
//

import SwiftUI
import SwiftData

struct ExpensesView: View {
    @Environment(\.modelContext) private var modelContext
    @EnvironmentObject var dataManager: DataManager
    
    @State private var selectedSection: ExpenseSection = .transactions
    
    enum ExpenseSection: String, CaseIterable {
        case transactions = "Transactions"
        case analysis = "Analysis"
    }
    
    var body: some View {
        VStack(spacing: 0) {
            // Segmented Control
            Picker("Expense Section", selection: $selectedSection) {
                ForEach(ExpenseSection.allCases, id: \.self) { section in
                    Text(section.rawValue)
                        .tag(section)
                }
            }
            .pickerStyle(SegmentedPickerStyle())
            .padding(.horizontal, 16)
            .padding(.vertical, 12)
            .background(Color(.systemGroupedBackground))
            
            // Content Section - Using ZStack to preserve view state
            ZStack {
                // Transactions View
                TransactionHistoryView()
                    .opacity(selectedSection == .transactions ? 1 : 0)
                    .allowsHitTesting(selectedSection == .transactions)
                
                // Analysis View
                if #available(iOS 16.0, *) {
                    SpendingChartView(dataManager: dataManager, showNavigationTitle: false)
                        .opacity(selectedSection == .analysis ? 1 : 0)
                        .allowsHitTesting(selectedSection == .analysis)
                } else {
                    Text("Analysis requires iOS 16+")
                        .foregroundColor(.secondary)
                        .opacity(selectedSection == .analysis ? 1 : 0)
                        .allowsHitTesting(selectedSection == .analysis)
                }
            }
            .animation(.easeInOut(duration: 0.3), value: selectedSection)
        }
        .navigationTitle("Expenses")
        .navigationBarTitleDisplayMode(.large)
        .background(Color(.systemGroupedBackground))
        .accessibilityLabel("Expenses View")
        .accessibilityHint("Switch between transaction management and spending analysis")
    }
}

#Preview {
    let config = ModelConfiguration(isStoredInMemoryOnly: true)
    let container = try! ModelContainer(for: Transaction.self, Budget.self, User.self, configurations: config)
    let context = ModelContext(container)
    
    return ExpensesView()
        .environmentObject(DataManager(modelContext: context))
        .modelContainer(container)
}
