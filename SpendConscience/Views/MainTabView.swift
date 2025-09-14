//
//  MainTabView.swift
//  SpendConscience
//
//  Created by AI Assistant
//

import SwiftUI
import SwiftData

struct MainTabView: View {
    @EnvironmentObject var userManager: UserManager
    @EnvironmentObject var dataManager: DataManager
    @Environment(\.modelContext) private var modelContext
    
    @State private var homePath = NavigationPath()
    @State private var expensesPath = NavigationPath()
    @State private var profilePath = NavigationPath()
    
    var body: some View {
        TabView {
            // Home Tab - Budget Dashboard
            NavigationStack(path: $homePath) {
                BudgetDashboardView()
                    .environmentObject(dataManager)
                    .environment(\.modelContext, modelContext)
                    .environment(\.navigationPath, $homePath)
                    .environment(\.navigate) { destination in
                        homePath.append(destination)
                    }
                    .navigationTitle("Budget Dashboard")
                    .navigationBarTitleDisplayMode(.large)
                    .navigationDestination(for: Destination.self) { destination in
                        navigationDestinationView(for: destination)
                    }
            }
            .tabItem {
                Image(systemName: "house.fill")
                Text("Home")
            }
            .accessibilityLabel("Home tab, Budget Dashboard")
            
            // Expenses Tab - Unified Expenses View
            NavigationStack(path: $expensesPath) {
                ExpensesView()
                    .environmentObject(dataManager)
                    .environment(\.modelContext, modelContext)
                    .environment(\.navigationPath, $expensesPath)
                    .environment(\.navigate) { destination in
                        expensesPath.append(destination)
                    }
                    .navigationDestination(for: Destination.self) { destination in
                        navigationDestinationView(for: destination)
                    }
            }
            .tabItem {
                Image(systemName: "creditcard.fill")
                Text("Expenses")
            }
            .accessibilityLabel("Expenses tab, Transaction History and Analysis")
            
            // Profile Tab
            NavigationStack(path: $profilePath) {
                ProfileView()
                    .environmentObject(userManager)
                    .environment(\.navigationPath, $profilePath)
                    .environment(\.navigate) { destination in
                        profilePath.append(destination)
                    }
                    .navigationTitle("Profile")
                    .navigationBarTitleDisplayMode(.large)
                    .navigationDestination(for: Destination.self) { destination in
                        navigationDestinationView(for: destination)
                    }
            }
            .tabItem {
                Image(systemName: "person.fill")
                Text("Profile")
            }
            .accessibilityLabel("Profile tab, User Settings")
        }
        .tabViewStyle(.automatic)
    }
    
    // MARK: - Navigation Destination View
    
    @ViewBuilder
    private func navigationDestinationView(for destination: Destination) -> some View {
        switch destination {
        case .aiAssistant:
            AIFinancialAssistantView()
        
        case .budgetDetail(let budget):
            BudgetDetailView(budgetID: budget.id)
                .environmentObject(dataManager)
                .environmentObject(userManager)
        
        case .transactionDetail(let transaction):
            TransactionDetailView(transactionID: transaction.id)
                .environmentObject(dataManager)
                .environmentObject(userManager)
        
        case .transactionEdit(let transaction):
            TransactionEditView(transaction: transaction, dataManager: dataManager) {
                // Handle dismiss
            }
            .environmentObject(userManager)
        
        case .transactionHistory:
            TransactionHistoryView()
                .environmentObject(dataManager)
                .environmentObject(userManager)
        
        case .expenses:
            ExpensesView()
                .environmentObject(dataManager)
                .environmentObject(userManager)
        
        case .profile:
            ProfileView()
                .environmentObject(userManager)
                .environmentObject(dataManager)
        }
    }
}

#Preview {
    let config = ModelConfiguration(isStoredInMemoryOnly: true)
    let container = try! ModelContainer(for: Transaction.self, Budget.self, User.self, configurations: config)
    let context = ModelContext(container)
    
    return MainTabView()
        .environmentObject(UserManager())
        .environmentObject(DataManager(modelContext: context))
        .modelContainer(container)
}
