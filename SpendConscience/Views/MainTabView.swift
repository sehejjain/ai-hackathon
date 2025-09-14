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
    
    var body: some View {
        TabView {
            // Home Tab - Budget Dashboard
            NavigationStack {
                BudgetDashboardView()
                    .environmentObject(dataManager)
                    .environment(\.modelContext, modelContext)
                    .navigationTitle("Home")
                    .navigationBarTitleDisplayMode(.large)
            }
            .tabItem {
                Image(systemName: "house.fill")
                Text("Home")
            }
            .accessibilityLabel("Home tab, Budget Dashboard")
            
            // Expenses Tab - Unified Expenses View
            ExpensesView()
                .environmentObject(dataManager)
                .environment(\.modelContext, modelContext)
            .tabItem {
                Image(systemName: "creditcard.fill")
                Text("Expenses")
            }
            .accessibilityLabel("Expenses tab, Transaction History and Analysis")
            
            // Profile Tab
            NavigationStack {
                ProfileView()
                    .environmentObject(userManager)
                    .navigationTitle("Profile")
                    .navigationBarTitleDisplayMode(.large)
            }
            .tabItem {
                Image(systemName: "person.fill")
                Text("Profile")
            }
            .accessibilityLabel("Profile tab, User Settings")
        }
        .tabViewStyle(.automatic)
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
