//
//  BudgetDashboardView.swift
//  SpendConscience
//
//  Created by AI Assistant on 9/13/25.
//

import SwiftUI
import SwiftData
#if canImport(UIKit)
import UIKit
#endif

struct BudgetDashboardView: View {
    @ObservedObject var dataManager: DataManager
    let onAddBudget: (() -> Void)?
    @State private var isRefreshing = false
    
    init(dataManager: DataManager, onAddBudget: (() -> Void)? = nil) {
        self.dataManager = dataManager
        self.onAddBudget = onAddBudget
    }
    
    var body: some View {
        GeometryReader { geometry in
            ScrollView {
                LazyVStack(spacing: 20) {
                    // Status Overview Section
                    statusOverviewSection
                    
                    // Budget Progress Section
                    budgetProgressSection(geometry: geometry)
                    
                    // Spending Analysis Section
                    spendingAnalysisSection
                }
                .padding(.horizontal, 16)
                .padding(.top, 8)
            }
            .refreshable {
                await refreshData()
            }
        }
        .navigationTitle("Budget Dashboard")
        .navigationBarTitleDisplayMode(.large)
        .toolbar {
            ToolbarItem(placement: .navigationBarTrailing) {
                Button(action: {
                    Task {
                        await refreshData()
                    }
                }) {
                    Image(systemName: "arrow.clockwise")
                        .foregroundColor(.primary)
                }
                .disabled(isRefreshing)
            }
        }
        .overlay {
            if dataManager.isLoading && dataManager.budgets.isEmpty {
                loadingView
            }
        }
    }
    
    // MARK: - Status Overview Section
    
    private var statusOverviewSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text("Budget Status Overview")
                    .font(.title2)
                    .fontWeight(.semibold)
                    .foregroundColor(.primary)
                
                Spacer()
                
                if isRefreshing {
                    ProgressView()
                        .scaleEffect(0.8)
                }
            }
            .accessibilityElement(children: .combine)
            .accessibilityLabel("Budget Status Overview Section")
            
            if let error = dataManager.error {
                errorView(error: error)
            } else {
                statusCardsView
            }
        }
    }
    
    private var statusCardsView: some View {
        let budgetStatus = dataManager.getBudgetStatus()
        let totalBudgets = dataManager.budgets.count
        let safeCount = budgetStatus[.safe] ?? 0
        let warningCount = budgetStatus[.warning] ?? 0
        let dangerCount = budgetStatus[.danger] ?? 0
        
        // Determine overall health
        let overallHealth: String
        let overallHealthColor: Color
        let overallHealthIcon: String
        
        if totalBudgets == 0 {
            overallHealth = "No Data"
            overallHealthColor = .secondary
            overallHealthIcon = "chart.pie"
        } else if dangerCount > 0 {
            overallHealth = "Needs Attention"
            overallHealthColor = Color(.systemRed)
            overallHealthIcon = "exclamationmark.triangle.fill"
        } else if warningCount > 0 {
            overallHealth = "Monitor Closely"
            overallHealthColor = Color(.systemOrange)
            overallHealthIcon = "exclamationmark.circle.fill"
        } else {
            overallHealth = "Healthy"
            overallHealthColor = Color(.systemGreen)
            overallHealthIcon = "checkmark.circle.fill"
        }
        
        return VStack(spacing: 16) {
            // Overall summary row
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text("Total Budgets")
                        .font(.caption)
                        .fontWeight(.medium)
                        .foregroundColor(.secondary)
                    
                    Text("\(totalBudgets)")
                        .font(.title)
                        .fontWeight(.bold)
                        .foregroundColor(.primary)
                }
                
                Spacer()
                
                VStack(alignment: .trailing, spacing: 4) {
                    Text("Overall Health")
                        .font(.caption)
                        .fontWeight(.medium)
                        .foregroundColor(.secondary)
                    
                    HStack(spacing: 6) {
                        Image(systemName: overallHealthIcon)
                            .font(.title3)
                            .foregroundColor(overallHealthColor)
                        
                        Text(overallHealth)
                            .font(.headline)
                            .fontWeight(.semibold)
                            .foregroundColor(overallHealthColor)
                    }
                }
            }
            .padding(16)
            .background(
                RoundedRectangle(cornerRadius: 12)
                    .fill(Color(.systemGray6))
                    .shadow(color: .black.opacity(0.05), radius: 4, x: 0, y: 2)
            )
            .accessibilityElement(children: .combine)
            .accessibilityLabel("Total budgets: \(totalBudgets), Overall health: \(overallHealth)")
            
            // Status cards grid
            LazyVGrid(columns: [
                GridItem(.adaptive(minimum: 140), spacing: 12)
            ], spacing: 12) {
                StatusCard(
                    title: "Safe",
                    count: safeCount,
                    color: Color(.systemGreen),
                    icon: "checkmark.circle.fill"
                )
                
                StatusCard(
                    title: "Warning",
                    count: warningCount,
                    color: Color(.systemOrange),
                    icon: "exclamationmark.triangle.fill"
                )
                
                StatusCard(
                    title: "Danger",
                    count: dangerCount,
                    color: Color(.systemRed),
                    icon: "xmark.circle.fill"
                )
            }
            .accessibilityElement(children: .contain)
            .accessibilityLabel("Budget status breakdown")
        }
    }
    
    // MARK: - Budget Progress Section
    
    private func budgetProgressSection(geometry: GeometryProxy) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Budget Progress")
                .font(.title2)
                .fontWeight(.semibold)
                .foregroundColor(.primary)
                .accessibilityAddTraits(.isHeader)
            
            if dataManager.budgets.isEmpty {
                emptyBudgetsView
            } else {
                budgetProgressGrid(geometry: geometry)
            }
        }
    }
    
    private func budgetProgressGrid(geometry: GeometryProxy) -> some View {
        let columns = adaptiveColumns(for: geometry.size.width)
        
        return LazyVGrid(columns: columns, spacing: 16) {
            ForEach(dataManager.budgets) { budget in
                BudgetProgressView(budget: budget)
                    .accessibilityElement(children: .combine)
                    .accessibilityLabel("Budget progress for \(budget.category.displayName)")
            }
        }
        .accessibilityElement(children: .contain)
        .accessibilityLabel("Budget progress grid with \(dataManager.budgets.count) budgets")
    }
    
    private var emptyBudgetsView: some View {
        VStack(spacing: 16) {
            Image(systemName: "chart.pie")
                .font(.system(size: 48))
                .foregroundColor(.secondary)
            
            Text("No Budgets Yet")
                .font(.title3)
                .fontWeight(.medium)
                .foregroundColor(.primary)
            
            Text("Create your first budget to start tracking your spending and financial goals.")
                .font(.body)
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 20)
            
            Button(action: {
                onAddBudget?()
            }) {
                HStack {
                    Image(systemName: "plus.circle.fill")
                    Text("Add Budget")
                }
                .font(.headline)
                .foregroundColor(.white)
                .padding(.horizontal, 24)
                .padding(.vertical, 12)
                .background(Color.accentColor)
                .cornerRadius(25)
            }
            .accessibilityLabel("Add your first budget")
            .accessibilityHint("Tap to create a new budget")
        }
        .padding(.vertical, 40)
        .frame(maxWidth: .infinity)
        .background(
            RoundedRectangle(cornerRadius: 16)
                .fill(Color(.systemGray6))
                .shadow(color: .black.opacity(0.05), radius: 8, x: 0, y: 2)
        )
        .accessibilityElement(children: .combine)
        .accessibilityLabel("No budgets available. Add your first budget to get started.")
    }
    
    // MARK: - Spending Analysis Section
    
    private var spendingAnalysisSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Spending Analysis")
                .font(.title2)
                .fontWeight(.semibold)
                .foregroundColor(.primary)
                .accessibilityAddTraits(.isHeader)
            
            SpendingChartView(dataManager: dataManager, showNavigationTitle: false)
                .accessibilityElement(children: .combine)
                .accessibilityLabel("Spending analysis charts")
        }
    }
    
    // MARK: - Supporting Views
    
    private var loadingView: some View {
        VStack(spacing: 16) {
            ProgressView()
                .scaleEffect(1.2)
            
            Text("Loading Dashboard...")
                .font(.headline)
                .foregroundColor(.secondary)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Color(.systemBackground))
        .accessibilityElement(children: .combine)
        .accessibilityLabel("Loading budget dashboard")
    }
    
    private func errorView(error: Error) -> some View {
        VStack(spacing: 12) {
            Image(systemName: "exclamationmark.triangle")
                .font(.system(size: 32))
                .foregroundColor(.red)
            
            Text("Unable to Load Data")
                .font(.headline)
                .foregroundColor(.primary)
            
            Text(error.localizedDescription)
                .font(.body)
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
            
            Button("Retry") {
                Task {
                    await refreshData()
                }
            }
            .buttonStyle(.borderedProminent)
            .disabled(isRefreshing)
        }
        .padding()
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(Color(.systemGray6))
        )
        .accessibilityElement(children: .combine)
        .accessibilityLabel("Error loading data: \(error.localizedDescription)")
        .accessibilityHint("Tap retry to reload")
    }
    
    // MARK: - Helper Methods
    
    private func adaptiveColumns(for width: CGFloat) -> [GridItem] {
        // Use GridItem(.adaptive) to let SwiftUI handle the layout automatically
        return [GridItem(.adaptive(minimum: 300), spacing: 16)]
    }
    
    @MainActor
    private func refreshData() async {
        isRefreshing = true
        defer { isRefreshing = false }
        
        // Add haptic feedback
        #if canImport(UIKit)
        let impactFeedback = UIImpactFeedbackGenerator(style: .light)
        impactFeedback.impactOccurred()
        #endif
        
        // Trigger data refresh in DataManager
        await dataManager.loadAllData()
    }
}

// MARK: - Status Card Component

struct StatusCard: View {
    let title: String
    let count: Int
    let color: Color
    let icon: String
    
    var body: some View {
        VStack(spacing: 8) {
            HStack {
                Image(systemName: icon)
                    .font(.title3)
                    .foregroundColor(color)
                
                Spacer()
                
                Text("\(count)")
                    .font(.title2)
                    .fontWeight(.bold)
                    .foregroundColor(.primary)
            }
            
            HStack {
                Text(title)
                    .font(.caption)
                    .fontWeight(.medium)
                    .foregroundColor(.secondary)
                
                Spacer()
            }
        }
        .padding(12)
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(Color(.systemBackground))
                .shadow(color: .black.opacity(0.05), radius: 4, x: 0, y: 2)
        )
        .overlay(
            RoundedRectangle(cornerRadius: 12)
                .stroke(color.opacity(0.2), lineWidth: 1)
        )
        .accessibilityElement(children: .combine)
        .accessibilityLabel("\(count) budgets in \(title.lowercased()) status")
        .accessibilityValue("\(count)")
    }
}

// MARK: - Preview Provider

struct BudgetDashboardView_Previews: PreviewProvider {
    static var previews: some View {
        Group {
            // Preview with data
            BudgetDashboardView(dataManager: previewDataManager())
                .previewDisplayName("With Data")
            
            // Preview with empty state
            BudgetDashboardView(dataManager: emptyDataManager())
                .previewDisplayName("Empty State")
            
            // Preview with loading state
            BudgetDashboardView(dataManager: loadingDataManager())
                .previewDisplayName("Loading State")
            
            // Dark mode preview
            BudgetDashboardView(dataManager: previewDataManager())
                .preferredColorScheme(.dark)
                .previewDisplayName("Dark Mode")
            
            // iPad preview
            BudgetDashboardView(dataManager: previewDataManager())
                .previewDevice("iPad Pro (12.9-inch) (6th generation)")
                .previewDisplayName("iPad")
        }
    }
    
    static func previewDataManager() -> DataManager {
        do {
            let config = ModelConfiguration(isStoredInMemoryOnly: true)
            let container = try ModelContainer(for: Budget.self, Transaction.self, configurations: config)
            let manager = DataManager(modelContext: container.mainContext)
            
            // Create sample budgets with different statuses
            let groceriesBudget = try Budget(category: .groceries, monthlyLimit: 500, currentSpent: 150)
            let entertainmentBudget = try Budget(category: .entertainment, monthlyLimit: 200, currentSpent: 160)
            let transportBudget = try Budget(category: .transportation, monthlyLimit: 300, currentSpent: 320)
            
            manager.budgets = [groceriesBudget, entertainmentBudget, transportBudget]
            return manager
        } catch {
            // Fallback to empty manager if preview setup fails
            let config = ModelConfiguration(isStoredInMemoryOnly: true)
            let container = try! ModelContainer(for: Budget.self, Transaction.self, configurations: config)
            return DataManager(modelContext: container.mainContext)
        }
    }
    
    static func emptyDataManager() -> DataManager {
        do {
            let config = ModelConfiguration(isStoredInMemoryOnly: true)
            let container = try ModelContainer(for: Budget.self, Transaction.self, configurations: config)
            let manager = DataManager(modelContext: container.mainContext)
            manager.budgets = []
            return manager
        } catch {
            // This should never fail in preview, but provide fallback
            fatalError("Failed to create preview data manager: \(error)")
        }
    }
    
    static func loadingDataManager() -> DataManager {
        do {
            let config = ModelConfiguration(isStoredInMemoryOnly: true)
            let container = try ModelContainer(for: Budget.self, Transaction.self, configurations: config)
            let manager = DataManager(modelContext: container.mainContext)
            manager.budgets = []
            return manager
        } catch {
            // This should never fail in preview, but provide fallback
            fatalError("Failed to create preview data manager: \(error)")
        }
    }
}
