import SwiftUI
import Foundation

struct AIInsightsBanner: View {
    let aiResponse: SpendConscienceData?
    let onViewDetails: () -> Void
    let error: Error?
    let isLoading: Bool
    
    @State private var isVisible = false
    @State private var showingAgentDetails = false
    
    // AI insight types for different styling
    enum InsightType {
        case budgetWarning
        case spendingRecommendation
        case financialAdvice
        case affordabilityCheck
        case general
        
        var color: Color {
            switch self {
            case .budgetWarning: return .orange
            case .spendingRecommendation: return .blue
            case .financialAdvice: return .green
            case .affordabilityCheck: return .purple
            case .general: return .blue
            }
        }
        
        var icon: String {
            switch self {
            case .budgetWarning: return "exclamationmark.triangle.fill"
            case .spendingRecommendation: return "chart.bar.fill"
            case .financialAdvice: return "lightbulb.fill"
            case .affordabilityCheck: return "dollarsign.circle.fill"
            case .general: return "brain.head.profile"
            }
        }
    }
    
    // Convenience initializer for existing usage
    init(aiResponse: SpendConscienceData?, onViewDetails: @escaping () -> Void) {
        self.aiResponse = aiResponse
        self.onViewDetails = onViewDetails
        self.error = nil
        self.isLoading = false
    }
    
    // Enhanced initializer with error handling
    init(aiResponse: SpendConscienceData?, onViewDetails: @escaping () -> Void, error: Error? = nil, isLoading: Bool = false) {
        self.aiResponse = aiResponse
        self.onViewDetails = onViewDetails
        self.error = error
        self.isLoading = isLoading
    }
    
    var body: some View {
        Group {
            if isLoading {
                loadingView
            } else if let error = error {
                errorView(error)
            } else if let response = aiResponse, !response.response.isEmpty {
                successView(response)
            }
        }
    }
    
    // MARK: - Loading View
    
    private var loadingView: some View {
        VStack(spacing: 12) {
            HStack(spacing: 8) {
                ProgressView()
                    .scaleEffect(0.8)
                
                Text("Getting AI insights...")
                    .font(.headline)
                    .foregroundColor(.primary)
                
                Spacer()
            }
            
            Text("Our AI agents are analyzing your financial data to provide personalized recommendations.")
                .font(.subheadline)
                .foregroundColor(.secondary)
                .multilineTextAlignment(.leading)
        }
        .padding()
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(Color(.systemBackground))
                .shadow(color: .black.opacity(0.05), radius: 4, x: 0, y: 2)
        )
        .overlay(
            RoundedRectangle(cornerRadius: 12)
                .stroke(Color.blue.opacity(0.2), lineWidth: 1)
        )
        .accessibilityLabel("Loading AI insights")
    }
    
    // MARK: - Error View
    
    private func errorView(_ error: Error) -> some View {
        VStack(spacing: 12) {
            HStack(spacing: 8) {
                Image(systemName: "exclamationmark.triangle.fill")
                    .foregroundColor(.orange)
                    .font(.title3)
                
                Text("AI Insights Unavailable")
                    .font(.headline)
                    .foregroundColor(.primary)
                
                Spacer()
                
                Button("Retry") {
                    // Trigger retry through the parent view
                    onViewDetails()
                }
                .font(.caption)
                .padding(.horizontal, 8)
                .padding(.vertical, 4)
                .background(Color.orange.opacity(0.1))
                .foregroundColor(.orange)
                .cornerRadius(8)
            }
            
            Text(errorMessage(for: error))
                .font(.subheadline)
                .foregroundColor(.secondary)
                .multilineTextAlignment(.leading)
        }
        .padding()
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(Color(.systemBackground))
                .shadow(color: .black.opacity(0.05), radius: 4, x: 0, y: 2)
        )
        .overlay(
            RoundedRectangle(cornerRadius: 12)
                .stroke(Color.orange.opacity(0.2), lineWidth: 1)
        )
        .accessibilityLabel("AI insights error: \(errorMessage(for: error))")
    }
    
    // MARK: - Success View
    
    private func successView(_ response: SpendConscienceData) -> some View {
            VStack(alignment: .leading, spacing: 12) {
                // Header with AI indicator and agent count
                headerView(response)
                
                // Main insight content
                insightContentView(response)
                
                // Agent flow summary (expandable)
                if !response.agentFlow.isEmpty {
                    agentFlowView(response.agentFlow)
                }
                
                // Sync status and timestamp
                syncStatusView(response)
            }
            .padding()
            .background(
                RoundedRectangle(cornerRadius: 12)
                    .fill(Color(.systemBackground))
                    .shadow(color: .black.opacity(0.1), radius: 4, x: 0, y: 2)
            )
            .overlay(
                RoundedRectangle(cornerRadius: 12)
                    .stroke(insightType(for: response.response).color.opacity(0.3), lineWidth: 1)
            )
            .scaleEffect(isVisible ? 1.0 : 0.95)
            .opacity(isVisible ? 1.0 : 0.0)
            .animation(.spring(response: 0.6, dampingFraction: 0.8), value: isVisible)
            .onAppear {
                withAnimation {
                    isVisible = true
                }
            }
            .accessibilityLabel("AI Financial Insights from \(aiResponse?.agentFlow.count ?? 0) agents")
            .accessibilityHint("Shows AI-generated recommendations about your budget and spending from multiple AI agents")
        }
    
    // MARK: - Header View
    
    private func headerView(_ response: SpendConscienceData) -> some View {
        HStack(spacing: 8) {
            // AI Icon with insight type color
            Image(systemName: insightType(for: response.response).icon)
                .foregroundColor(insightType(for: response.response).color)
                .font(.title2)
            
            VStack(alignment: .leading, spacing: 2) {
                Text("AI Financial Insights")
                    .font(.headline)
                    .foregroundColor(.primary)
                
                // Agent count and mode indicator
                Text("\(response.agentFlow.count) agents • \(response.mode.capitalized)")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            
            Spacer()
            
            // View Details button
            Button(action: onViewDetails) {
                HStack(spacing: 4) {
                    Text("View Details")
                        .font(.caption)
                    Image(systemName: "chevron.right")
                        .font(.caption2)
                }
                .foregroundColor(insightType(for: response.response).color)
                .padding(.horizontal, 8)
                .padding(.vertical, 4)
                .background(insightType(for: response.response).color.opacity(0.1))
                .cornerRadius(8)
            }
            .accessibilityLabel("View detailed AI analysis")
        }
    }
    
    // MARK: - Insight Content View
    
    private func insightContentView(_ response: SpendConscienceData) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(truncatedInsight(response.response))
                .font(.subheadline)
                .foregroundColor(.primary)
                .lineLimit(showingAgentDetails ? nil : 3)
                .multilineTextAlignment(.leading)
            
            // Show spending data if available
            if let plaidData = response.plaidData {
                plaidDataSummary(plaidData)
            }
        }
    }
    
    // MARK: - Agent Flow View
    
    private func agentFlowView(_ agentFlow: [AgentFlowStep]) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            Button(action: {
                withAnimation(.easeInOut(duration: 0.3)) {
                    showingAgentDetails.toggle()
                }
            }) {
                HStack(spacing: 4) {
                    Text("Agent Analysis")
                        .font(.caption)
                        .fontWeight(.medium)
                    Image(systemName: showingAgentDetails ? "chevron.up" : "chevron.down")
                        .font(.caption2)
                }
                .foregroundColor(.secondary)
            }
            
            if showingAgentDetails {
                VStack(alignment: .leading, spacing: 4) {
                    ForEach(agentFlow) { step in
                        HStack(spacing: 8) {
                            Circle()
                                .fill(agentColor(for: step.agent))
                                .frame(width: 6, height: 6)
                            
                            Text(step.agent)
                                .font(.caption2)
                                .fontWeight(.medium)
                                .foregroundColor(.primary)
                            
                            Text("•")
                                .foregroundColor(.secondary)
                                .font(.caption2)
                            
                            Text(step.action)
                                .font(.caption2)
                                .foregroundColor(.secondary)
                            
                            Spacer()
                        }
                    }
                }
                .padding(.leading, 8)
                .transition(.slide.combined(with: .opacity))
            }
        }
    }
    
    // MARK: - Sync Status View
    
    private func syncStatusView(_ response: SpendConscienceData) -> some View {
        HStack {
            Image(systemName: "cloud.fill")
                .foregroundColor(.green)
                .font(.caption2)
            
            Text("Updated \(formatTimestamp(response.timestamp))")
                .font(.caption2)
                .foregroundColor(.secondary)
            
            Spacer()
            
            // Data source indicator
            HStack(spacing: 4) {
                Image(systemName: "brain")
                    .font(.caption2)
                Text("AI Processed")
                    .font(.caption2)
            }
            .foregroundColor(.blue)
            .padding(.horizontal, 6)
            .padding(.vertical, 2)
            .background(Color.blue.opacity(0.1))
            .cornerRadius(4)
        }
    }
    
    // MARK: - Plaid Data Summary
    
    private func plaidDataSummary(_ plaidData: PlaidDataSummary) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack {
                Text("Available Funds:")
                    .font(.caption)
                    .foregroundColor(.secondary)
                Spacer()
                Text("$\(plaidData.availableFunds, specifier: "%.2f")")
                    .font(.caption)
                    .fontWeight(.medium)
                    .foregroundColor(.primary)
            }
            
            if plaidData.totalSpending > 0 {
                HStack {
                    Text("Monthly Spending:")
                        .font(.caption)
                        .foregroundColor(.secondary)
                    Spacer()
                    Text("$\(plaidData.totalSpending, specifier: "%.2f")")
                        .font(.caption)
                        .fontWeight(.medium)
                        .foregroundColor(.primary)
                }
            }
        }
        .padding(.top, 4)
        .padding(.horizontal, 8)
        .background(Color(.systemGray6))
        .cornerRadius(6)
    }
    
    // MARK: - Helper Methods
    
    private func errorMessage(for error: Error) -> String {
        if let apiError = error as? SpendConscienceAPIError {
            switch apiError {
            case .locationDenied:
                return "Location access is required for restaurant recommendations. Please enable location services in Settings."
            case .locationUnavailable:
                return "Location services are currently unavailable. Some features may be limited."
            case .networkError:
                return "Unable to connect to AI services. Please check your internet connection."
            case .serverError:
                return "AI services are temporarily unavailable. Please try again later."
            default:
                return "Unable to get AI insights at the moment. Please try again."
            }
        } else {
            return "AI insights are temporarily unavailable. Your budget data remains accessible offline."
        }
    }
    
    private func insightType(for text: String) -> InsightType {
        let lowercased = text.lowercased()
        
        if lowercased.contains("warning") || lowercased.contains("exceed") || lowercased.contains("over budget") {
            return .budgetWarning
        } else if lowercased.contains("afford") || lowercased.contains("purchase") {
            return .affordabilityCheck
        } else if lowercased.contains("save") || lowercased.contains("advice") || lowercased.contains("recommend") {
            return .financialAdvice
        } else if lowercased.contains("spending") || lowercased.contains("category") {
            return .spendingRecommendation
        } else {
            return .general
        }
    }
    
    private func agentColor(for agentName: String) -> Color {
        switch agentName.lowercased() {
        case let name where name.contains("budget"):
            return .orange
        case let name where name.contains("affordability"):
            return .purple
        case let name where name.contains("financial"):
            return .green
        case let name where name.contains("coach"):
            return .blue
        default:
            return .gray
        }
    }
    
    private func formatTimestamp(_ timestamp: String) -> String {
        let formatter = ISO8601DateFormatter()
        if let date = formatter.date(from: timestamp) {
            let timeFormatter = DateFormatter()
            timeFormatter.timeStyle = .short
            timeFormatter.dateStyle = .none
            
            let calendar = Calendar.current
            if calendar.isDateInToday(date) {
                return "today at \(timeFormatter.string(from: date))"
            } else if calendar.isDateInYesterday(date) {
                return "yesterday at \(timeFormatter.string(from: date))"
            } else {
                timeFormatter.dateStyle = .short
                return timeFormatter.string(from: date)
            }
        }
        return "recently"
    }
    
    private func truncatedInsight(_ text: String) -> String {
        let maxLength = showingAgentDetails ? 300 : 150
        if text.count <= maxLength {
            return text
        }
        
        let truncated = String(text.prefix(maxLength))
        if let lastSpace = truncated.lastIndex(of: " ") {
            return String(truncated[..<lastSpace]) + "..."
        }
        return truncated + "..."
    }
}

struct AIInsightsBanner_Previews: PreviewProvider {
    static var previews: some View {
        VStack(spacing: 20) {
            // Budget Warning Example
            AIInsightsBanner(
                aiResponse: SpendConscienceData(
                    query: "How is my budget this month?",
                    userId: "preview-user",
                    response: "⚠️ Warning: You're on track to exceed your dining budget by 15% this month. You've spent $345 of your $300 monthly limit with 8 days remaining. Consider reducing restaurant visits or exploring more affordable dining options to avoid overspending.",
                    agentFlow: [
                        AgentFlowStep(agent: "Budget Analyzer", action: "Analyzed spending patterns and detected budget overrun"),
                        AgentFlowStep(agent: "Affordability Agent", action: "Calculated remaining budget capacity"),
                        AgentFlowStep(agent: "Financial Coach", action: "Generated cost-saving recommendations"),
                        AgentFlowStep(agent: "Transaction Monitor", action: "Identified high-spend categories")
                    ],
                    plaidData: PlaidDataSummary(
                        accounts: [],
                        spendingByCategory: ["Food and Drink": 345.67, "Transportation": 123.45],
                        totalSpending: 1234.56,
                        availableFunds: 2456.78
                    ),
                    timestamp: "2025-09-14T09:30:00.000Z",
                    mode: "budget-analysis"
                ),
                onViewDetails: {}
            )
            
            // Positive Financial Advice Example
            AIInsightsBanner(
                aiResponse: SpendConscienceData(
                    query: "How is my grocery spending?",
                    userId: "preview-user",
                    response: "💡 Excellent job staying within your grocery budget! You've spent $280 of your $400 limit with 10 days left in the month. Your consistent shopping habits and smart meal planning are helping you maintain financial discipline. Consider allocating $50 of the remaining budget to stock up on staples.",
                    agentFlow: [
                        AgentFlowStep(agent: "Budget Analyzer", action: "Analyzed grocery spending trends"),
                        AgentFlowStep(agent: "Financial Coach", action: "Provided positive reinforcement"),
                        AgentFlowStep(agent: "Smart Planner", action: "Suggested optimal budget allocation")
                    ],
                    plaidData: PlaidDataSummary(
                        accounts: [],
                        spendingByCategory: ["Groceries": 280.00, "Household": 45.50],
                        totalSpending: 890.25,
                        availableFunds: 3245.67
                    ),
                    timestamp: "2025-09-14T14:15:30.000Z",
                    mode: "budget-analysis"
                ),
                onViewDetails: {}
            )
            
            // Affordability Check Example
            AIInsightsBanner(
                aiResponse: SpendConscienceData(
                    query: "Can I afford a $75 dinner tonight?",
                    userId: "preview-user",
                    response: "✅ Yes, you can afford this $75 dinner expense! It represents only 3% of your available funds and fits within your dining budget. However, I found 3 excellent restaurants nearby with similar cuisine for $45-55 that could save you $20-30 while still enjoying a great meal.",
                    agentFlow: [
                        AgentFlowStep(agent: "Affordability Agent", action: "Calculated expense impact on available funds"),
                        AgentFlowStep(agent: "Budget Monitor", action: "Checked against dining budget limits"),
                        AgentFlowStep(agent: "Location Scout", action: "Found nearby restaurant alternatives"),
                        AgentFlowStep(agent: "Savings Optimizer", action: "Calculated potential savings")
                    ],
                    plaidData: PlaidDataSummary(
                        accounts: [],
                        spendingByCategory: ["Food and Drink": 245.30],
                        totalSpending: 1456.78,
                        availableFunds: 2890.45
                    ),
                    timestamp: "2025-09-14T18:45:12.000Z",
                    mode: "affordability-check"
                ),
                onViewDetails: {}
            )
            
            // Empty state
            AIInsightsBanner(aiResponse: nil, onViewDetails: {})
        }
        .padding()
        .background(Color(.systemGroupedBackground))
        .previewDisplayName("AI Insights Banner Variants")
    }
}
