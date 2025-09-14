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
    @EnvironmentObject var dataManager: DataManager
    @Environment(\.navigate) var navigate
    let onAddBudget: (() -> Void)?
    @State private var isRefreshing = false
    
    init(onAddBudget: (() -> Void)? = nil) {
        self.onAddBudget = onAddBudget
    }
    
    // MARK: - AI System Status Indicator
    
    private var aiSystemStatusIndicator: some View {
        HStack(spacing: 4) {
            let (status, color, icon) = getAISystemStatus()
            
            Image(systemName: icon)
                .font(.caption2)
                .foregroundColor(color)
            
            Text(status)
                .font(.caption2)
                .foregroundColor(color)
        }
        .padding(.horizontal, 6)
        .padding(.vertical, 2)
        .background(
            RoundedRectangle(cornerRadius: 4)
                .fill(getAISystemStatus().1.opacity(0.1))
        )
        .accessibilityLabel("AI system status: \(getAISystemStatus().0)")
    }
    
    private func getAISystemStatus() -> (String, Color, String) {
        if dataManager.apiService.isLoading {
            return ("Processing", .blue, "brain")
        } else if dataManager.apiService.currentError != nil {
            return ("Offline", .orange, "wifi.slash")
        } else if dataManager.apiService.isConnected {
            return ("AI Active", .green, "brain.head.profile")
        } else {
            return ("Local Mode", .secondary, "circle.fill")
        }
    }
    
    // MARK: - AI-Powered Recommendations
    
    var body: some View {
        ZStack {
            GeometryReader { geometry in
                ScrollView {
                    LazyVStack(spacing: 20) {
                        // AI Insights Banner
                        aiInsightsBanner
                        
                        // Status Overview Section
                        statusOverviewSection
                        
                        // Budget Progress Section
                        budgetProgressSection(geometry: geometry)
                        
                        // Spending Analysis Section
                        spendingAnalysisSection
                    }
                    .padding(.horizontal, 16)
                    .padding(.top, 8)
                    .padding(.bottom, 16) // Reduced padding, FAB will handle safe area
                }
                .refreshable {
                    await refreshData()
                }
            }
            .overlay {
                if dataManager.isLoading && dataManager.budgets.isEmpty {
                    loadingView
                }
            }
            
            // Floating Action Button positioned at bottom-right
            VStack {
                Spacer()
                HStack {
                    Spacer()
                    let isBlockingLoad = dataManager.isLoading && dataManager.budgets.isEmpty
                    FloatingActionButton {
                        navigateToAIAssistant(navigate)
                    }
                    .padding(.trailing, 16)
                    .disabled(isBlockingLoad)
                    .opacity(isBlockingLoad ? 0 : 1)
                    .accessibilityHidden(isBlockingLoad)
                }
            }
            .safeAreaInset(edge: .bottom) {
                Color.clear.frame(height: 16)
            }
        }
    }
    
    // MARK: - AI Insights Banner
    
    private var aiInsightsBanner: some View {
        AIInsightsBanner(
            aiResponse: dataManager.apiService.currentResponse,
            onViewDetails: {
                navigateToAIAssistant(navigate)
            }
        )
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
                } else {
                    // AI System Status Indicator
                    aiSystemStatusIndicator
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
            
            // AI-Powered Budget Recommendations
            aiPoweredRecommendations
        }
    }
    
    // MARK: - AI-Powered Recommendations
    
    private var aiPoweredRecommendations: some View {
        Group {
            if let aiResponse = dataManager.apiService.currentResponse,
               !aiResponse.response.isEmpty {
                VStack(alignment: .leading, spacing: 12) {
                    HStack {
                        Image(systemName: "sparkles")
                            .foregroundColor(.blue)
                            .font(.title3)
                        
                        Text("AI Budget Recommendations")
                            .font(.headline)
                            .fontWeight(.semibold)
                        
                        Spacer()
                        
                        // Last updated indicator
                        if let lastSync = getLastSyncTime() {
                            HStack(spacing: 4) {
                                Image(systemName: "clock")
                                    .font(.caption2)
                                Text(lastSync)
                                    .font(.caption2)
                            }
                            .foregroundColor(.secondary)
                        }
                    }
                    
                    // AI Recommendations based on 4-agent analysis
                    VStack(spacing: 8) {
                        ForEach(extractRecommendations(from: aiResponse), id: \.self) { recommendation in
                            HStack(alignment: .top, spacing: 8) {
                                Image(systemName: "lightbulb.fill")
                                    .foregroundColor(.orange)
                                    .font(.caption)
                                    .padding(.top, 2)
                                
                                Text(recommendation)
                                    .font(.subheadline)
                                    .foregroundColor(.primary)
                                    .multilineTextAlignment(.leading)
                                
                                Spacer()
                            }
                            .padding(.horizontal, 12)
                            .padding(.vertical, 8)
                            .background(
                                RoundedRectangle(cornerRadius: 8)
                                    .fill(Color(.systemGray6))
                            )
                        }
                    }
                    
                    // Budget optimization suggestions from AI
                    if hasOverBudgetCategories() {
                        budgetOptimizationSuggestions
                    }
                }
                .padding()
                .background(
                    RoundedRectangle(cornerRadius: 12)
                        .fill(Color(.systemBackground))
                        .shadow(color: .blue.opacity(0.1), radius: 4, x: 0, y: 2)
                )
                .overlay(
                    RoundedRectangle(cornerRadius: 12)
                        .stroke(Color.blue.opacity(0.2), lineWidth: 1)
                )
            }
        }
    }
    
    // MARK: - Budget Optimization Suggestions
    
    private var budgetOptimizationSuggestions: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Image(systemName: "chart.line.uptrend.xyaxis")
                    .foregroundColor(.green)
                    .font(.caption)
                
                Text("Optimization Opportunities")
                    .font(.caption)
                    .fontWeight(.semibold)
                    .foregroundColor(.secondary)
            }
            
            ForEach(getOverBudgetCategories(), id: \.id) { budget in
                HStack(spacing: 8) {
                    Image(systemName: budget.category.systemIcon)
                        .foregroundColor(.orange)
                        .font(.caption2)
                    
                    VStack(alignment: .leading, spacing: 2) {
                        Text(budget.category.displayName)
                            .font(.caption)
                            .fontWeight(.medium)
                        
                        Text(formatOverageAmount(for: budget))
                            .font(.caption2)
                            .foregroundColor(.secondary)
                    }
                    
                    Spacer()
                    
                    optimizeButton(for: budget)
                }
            }
        }
        .padding(.top, 8)
    }
    
    // Helper method to create optimize button with proper styling
    private func optimizeButton(for budget: Budget) -> some View {
        Button("Optimize") {
            navigate(.budgetDetail(budget))
        }
        .font(.caption2)
        .padding(.horizontal, 8)
        .padding(.vertical, 4)
        .background(Color.green.opacity(0.1))
        .foregroundColor(.green)
        .cornerRadius(4)
    }
    
    // Helper method to format overage amount
    private func formatOverageAmount(for budget: Budget) -> String {
        let overageDecimal = budget.currentSpent - budget.monthlyLimit
        let overageAmount = Double(truncating: NSDecimalNumber(decimal: overageDecimal))
        let formattedAmount = String(format: "%.2f", overageAmount)
        return "Over by $\(formattedAmount)"
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
            
            if let onAddBudget = onAddBudget {
                Button(action: onAddBudget) {
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
        LoadingPlaceholderView(title: "Loading Dashboard...")
    }
    
    private func errorView(error: Error) -> some View {
        VStack(spacing: 12) {
            Image(systemName: "exclamationmark.triangle")
                .font(.system(size: 32))
                .foregroundColor(.red)
            
            Text("Unable to Load Data")
                .font(.headline)
                .foregroundColor(.primary)
            
            Text(errorDescription(for: error))
                .font(.body)
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
            
            // Break down the button HStack into separate property
            errorActionButtons
        }
        .padding()
        .background(errorViewBackground)
        .accessibilityElement(children: .combine)
        .accessibilityLabel("Error loading data: \(errorDescription(for: error))")
        .accessibilityHint("Use retry button to reload data or continue with offline data")
    }
    
    // Extract the buttons into a separate computed property
    private var errorActionButtons: some View {
        HStack(spacing: 16) {
            retryButton
            offlineDataButton
        }
    }
    
    // Extract individual buttons
    private var retryButton: some View {
        Button("Retry") {
            Task {
                await refreshData()
            }
        }
        .buttonStyle(.borderedProminent)
        .disabled(isRefreshing)
    }
    
    private var offlineDataButton: some View {
        Button("Use Offline Data") {
            Task {
                await dataManager.loadAllData()
            }
        }
        .buttonStyle(.bordered)
        .disabled(isRefreshing)
    }
    
    // Extract the background into a separate computed property
    private var errorViewBackground: some View {
        RoundedRectangle(cornerRadius: 12)
            .fill(Color(.systemGray6))
    }
    
    private func errorDescription(for error: Error) -> String {
        if let apiError = error as? SpendConscienceAPIError {
            switch apiError {
            case .networkError:
                return "Check your internet connection and try again. You can continue using offline data in the meantime."
            case .serverError:
                return "Our AI services are temporarily unavailable. You can view your local budget data while we restore the service."
            case .locationDenied, .locationUnavailable:
                return "Location services are needed for restaurant recommendations. Your budget tracking will work normally."
            default:
                return "There was an issue loading your latest financial insights. Your local data remains available."
            }
        } else {
            return error.localizedDescription
        }
    }
    
    // MARK: - Helper Methods
    
    private func adaptiveColumns(for width: CGFloat) -> [GridItem] {
        // Use GridItem(.adaptive) to let SwiftUI handle the layout automatically
        return [GridItem(.adaptive(minimum: 300), spacing: 16)]
    }
    
    // MARK: - AI Helper Methods
    
    private func extractRecommendations(from response: SpendConscienceData) -> [String] {
        let text = response.response
        var recommendations: [String] = []
        
        // Extract bullet points or numbered recommendations
        let lines = text.components(separatedBy: .newlines)
        for line in lines {
            let trimmed = line.trimmingCharacters(in: .whitespacesAndNewlines)
            if trimmed.hasPrefix("•") || trimmed.hasPrefix("-") || trimmed.hasPrefix("*") {
                let recommendation = trimmed.dropFirst().trimmingCharacters(in: .whitespacesAndNewlines)
                if !recommendation.isEmpty {
                    recommendations.append(recommendation)
                }
            } else if trimmed.contains("consider") || trimmed.contains("recommend") || trimmed.contains("suggest") {
                // Extract sentences with recommendations
                let sentences = trimmed.components(separatedBy: ". ")
                for sentence in sentences {
                    if sentence.lowercased().contains("consider") ||
                       sentence.lowercased().contains("recommend") ||
                       sentence.lowercased().contains("suggest") {
                        recommendations.append(sentence.trimmingCharacters(in: .whitespacesAndNewlines))
                    }
                }
            }
        }
        
        // If no structured recommendations found, create general ones based on budget status
        if recommendations.isEmpty {
            recommendations = generateDefaultRecommendations()
        }
        
        return Array(recommendations.prefix(3)) // Limit to 3 recommendations
    }
    
    private func generateDefaultRecommendations() -> [String] {
        var recommendations: [String] = []
        let budgetStatus = dataManager.getBudgetStatus()
        
        if let dangerCount = budgetStatus[.danger], dangerCount > 0 {
            recommendations.append("Review and adjust budgets for categories that are over limit")
        }
        
        if let warningCount = budgetStatus[.warning], warningCount > 0 {
            recommendations.append("Monitor spending closely in categories approaching their limits")
        }
        
        if dataManager.budgets.count < 5 {
            recommendations.append("Consider creating budgets for additional spending categories")
        }
        
        return recommendations
    }
    
    private func getLastSyncTime() -> String? {
        // Check for recent backend sync dates in budgets
        let recentSyncs = dataManager.budgets.compactMap { $0.backendSyncDate }
        
        if let mostRecent = recentSyncs.max() {
            let formatter = DateFormatter()
            formatter.timeStyle = .short
            formatter.dateStyle = .none
            
            let calendar = Calendar.current
            if calendar.isDateInToday(mostRecent) {
                return "Updated \(formatter.string(from: mostRecent))"
            } else if calendar.isDateInYesterday(mostRecent) {
                return "Updated yesterday"
            } else {
                formatter.dateStyle = .short
                return "Updated \(formatter.string(from: mostRecent))"
            }
        }
        
        return nil
    }
    
    private func hasOverBudgetCategories() -> Bool {
        return dataManager.budgets.contains { $0.isOverBudget }
    }
    
    private func getOverBudgetCategories() -> [Budget] {
        return dataManager.budgets.filter { $0.isOverBudget }
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
        
        // Trigger data refresh in DataManager and sync with backend
        await dataManager.loadAllData()
        await dataManager.syncBudgetsWithBackend()
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
            BudgetDashboardView()
                .environmentObject(previewDataManager())
                .previewDisplayName("With Data")
            
            // Preview with empty state
            BudgetDashboardView()
                .environmentObject(emptyDataManager())
                .previewDisplayName("Empty State")
            
            // Preview with loading state
            BudgetDashboardView()
                .environmentObject(loadingDataManager())
                .previewDisplayName("Loading State")
            
            // Dark mode preview
            BudgetDashboardView()
                .environmentObject(previewDataManager())
                .preferredColorScheme(.dark)
                .previewDisplayName("Dark Mode")
            
            // iPad preview
            BudgetDashboardView()
                .environmentObject(previewDataManager())
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
