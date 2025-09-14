//
//  AIFinancialAssistantView.swift
//  SpendConscience
//
//  Enhanced AI-powered financial assistant using the Plaid-Inkeep integration
//

import SwiftUI

struct AIFinancialAssistantView: View {
    @StateObject private var apiService = SpendConscienceAPIService()
    @State private var queryText: String = ""
    @State private var showingQuickQuestions = false
    @State private var selectedQuickQuestion: String?
    
    private let quickQuestions = [
        "Can I afford a $75 dinner tonight?",
        "How is my budget this month?",
        "What are my largest expenses?",
        "Should I save more money?",
        "Can I afford a $1200 laptop?",
        "How much did I spend on food this week?"
    ]
    
    var body: some View {
        NavigationView {
            VStack(spacing: 0) {
                // Header
                headerView
                
                // Content
                ScrollView {
                    VStack(spacing: 20) {
                        // Connection Status
                        connectionStatusView
                        
                        // Response Section
                        if let response = apiService.currentResponse {
                            responseView(response)
                        } else if apiService.currentError != nil {
                            errorView
                        } else {
                            welcomeView
                        }
                        
                        // Quick Questions
                        quickQuestionsView
                    }
                    .padding()
                }
                
                // Input Section
                inputView
            }
            .navigationTitle("AI Financial Assistant")
            .navigationBarTitleDisplayMode(.large)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button(action: {
                        Task { await apiService.testConnection() }
                    }) {
                        Image(systemName: "arrow.clockwise")
                    }
                    .disabled(apiService.isLoading)
                }
            }
            .onAppear {
                Task { await apiService.testConnection() }
            }
        }
    }
    
    // MARK: - Header View
    
    private var headerView: some View {
        VStack(spacing: 8) {
            HStack {
                Image(systemName: "brain.head.profile")
                    .font(.title2)
                    .foregroundColor(.blue)
                
                VStack(alignment: .leading) {
                    Text("AI Financial Assistant")
                        .font(.headline)
                    Text("Powered by 4-Agent Intelligence")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                
                Spacer()
                
                if apiService.isLoading {
                    ProgressView()
                        .scaleEffect(0.8)
                }
            }
            .padding(.horizontal)
            .padding(.top, 8)
        }
        .background(Color(.systemGray6))
    }
    
    // MARK: - Connection Status View
    
    private var connectionStatusView: some View {
        HStack {
            Image(systemName: apiService.isConnected ? "checkmark.circle.fill" : "xmark.circle.fill")
                .foregroundColor(apiService.isConnected ? .green : .red)
            
            Text(apiService.isConnected ? "Connected to AI Agents" : "Disconnected")
                .font(.subheadline)
                .fontWeight(.medium)
            
            Spacer()
            
            Text("Plaid-Inkeep Integration")
                .font(.caption)
                .foregroundColor(.secondary)
        }
        .padding()
        .background(apiService.isConnected ? Color.green.opacity(0.1) : Color.red.opacity(0.1))
        .cornerRadius(12)
    }
    
    // MARK: - Welcome View
    
    private var welcomeView: some View {
        VStack(spacing: 16) {
            Image(systemName: "sparkles")
                .font(.system(size: 50))
                .foregroundColor(.blue)
            
            Text("Ask Your AI Financial Team")
                .font(.title2)
                .fontWeight(.semibold)
            
            Text("Get instant insights from our 4-agent system:\n• Budget Analyzer\n• Future Commitments\n• Affordability Agent\n• Financial Coach")
                .font(.subheadline)
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
            
            Text("Ask about spending, budgets, or financial decisions!")
                .font(.caption)
                .foregroundColor(.secondary)
        }
        .padding()
        .background(Color(.systemGray6))
        .cornerRadius(16)
    }
    
    // MARK: - Response View
    
    private func responseView(_ response: SpendConscienceData) -> some View {
        VStack(alignment: .leading, spacing: 16) {
            // Query
            HStack {
                Image(systemName: "questionmark.circle.fill")
                    .foregroundColor(.blue)
                Text("Your Question:")
                    .font(.headline)
                Spacer()
            }
            
            Text(response.query)
                .font(.subheadline)
                .padding()
                .background(Color.blue.opacity(0.1))
                .cornerRadius(12)
            
            // Agent Flow
            agentFlowView(response.agentFlow)
            
            // AI Response
            HStack {
                Image(systemName: "brain.head.profile")
                    .foregroundColor(.green)
                Text("AI Analysis:")
                    .font(.headline)
                Spacer()
            }
            
            Text(response.response)
                .font(.body)
                .padding()
                .background(Color.green.opacity(0.1))
                .cornerRadius(12)
            
            // Plaid Data Summary
            if let plaidData = response.plaidData {
                plaidDataView(plaidData)
            }
            
            // Clear Button
            HStack {
                Spacer()
                Button("Clear") {
                    apiService.clearResponse()
                }
                .buttonStyle(.bordered)
                .controlSize(.small)
            }
        }
        .padding()
        .background(Color(.systemBackground))
        .cornerRadius(16)
        .shadow(radius: 2)
    }
    
    // MARK: - Agent Flow View
    
    private func agentFlowView(_ agentFlow: [AgentFlowStep]) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Image(systemName: "arrow.triangle.branch")
                    .foregroundColor(.orange)
                Text("Agent Workflow:")
                    .font(.headline)
                Spacer()
            }
            
            VStack(spacing: 8) {
                ForEach(Array(agentFlow.enumerated()), id: \.element.id) { index, step in
                    HStack {
                        Text("\(index + 1)")
                            .font(.caption)
                            .fontWeight(.bold)
                            .foregroundColor(.white)
                            .frame(width: 20, height: 20)
                            .background(Color.orange)
                            .clipShape(Circle())
                        
                        VStack(alignment: .leading, spacing: 2) {
                            Text(step.agent)
                                .font(.subheadline)
                                .fontWeight(.semibold)
                            Text(step.action)
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                        
                        Spacer()
                    }
                    .padding(.vertical, 4)
                }
            }
            .padding()
            .background(Color.orange.opacity(0.1))
            .cornerRadius(12)
        }
    }
    
    // MARK: - Plaid Data View
    
    private func plaidDataView(_ plaidData: PlaidDataSummary) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Image(systemName: "creditcard.fill")
                    .foregroundColor(.purple)
                Text("Financial Data:")
                    .font(.headline)
                Spacer()
            }
            
            VStack(spacing: 12) {
                // Available Funds
                HStack {
                    Text("Available Funds:")
                        .fontWeight(.semibold)
                    Spacer()
                    Text("$\(plaidData.availableFunds, specifier: "%.2f")")
                        .fontWeight(.bold)
                        .foregroundColor(.green)
                }
                
                // Total Spending
                HStack {
                    Text("Monthly Spending:")
                        .fontWeight(.semibold)
                    Spacer()
                    Text("$\(plaidData.totalSpending, specifier: "%.2f")")
                        .fontWeight(.bold)
                        .foregroundColor(.orange)
                }
                
                Divider()
                
                // Spending Categories
                Text("Spending by Category:")
                    .font(.subheadline)
                    .fontWeight(.semibold)
                
                ForEach(plaidData.spendingByCategory.sorted(by: { $0.value > $1.value }), id: \.key) { category, amount in
                    HStack {
                        Text(category)
                            .font(.caption)
                        Spacer()
                        Text("$\(amount, specifier: "%.2f")")
                            .font(.caption)
                            .fontWeight(.medium)
                    }
                }
            }
            .padding()
            .background(Color.purple.opacity(0.1))
            .cornerRadius(12)
        }
    }
    
    // MARK: - Error View
    
    private var errorView: some View {
        VStack(spacing: 12) {
            Image(systemName: "exclamationmark.triangle.fill")
                .font(.system(size: 40))
                .foregroundColor(.red)
            
            Text("Connection Error")
                .font(.headline)
            
            if let error = apiService.currentError {
                Text(error.localizedDescription)
                    .font(.subheadline)
                    .foregroundColor(.secondary)
                    .multilineTextAlignment(.center)
            }
            
            Button("Retry Connection") {
                Task { await apiService.testConnection() }
            }
            .buttonStyle(.borderedProminent)
            .controlSize(.small)
        }
        .padding()
        .background(Color.red.opacity(0.1))
        .cornerRadius(16)
    }
    
    // MARK: - Quick Questions View
    
    private var quickQuestionsView: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Image(systemName: "lightbulb.fill")
                    .foregroundColor(.yellow)
                Text("Quick Questions:")
                    .font(.headline)
                Spacer()
            }
            
            LazyVGrid(columns: [
                GridItem(.flexible()),
                GridItem(.flexible())
            ], spacing: 8) {
                ForEach(quickQuestions, id: \.self) { question in
                    Button(action: {
                        Task {
                            await apiService.askFinancialQuestion(question)
                        }
                    }) {
                        Text(question)
                            .font(.caption)
                            .multilineTextAlignment(.center)
                            .padding(.horizontal, 8)
                            .padding(.vertical, 6)
                            .background(Color.blue.opacity(0.1))
                            .foregroundColor(.blue)
                            .cornerRadius(8)
                    }
                    .disabled(apiService.isLoading || !apiService.isConnected)
                }
            }
        }
    }
    
    // MARK: - Input View
    
    private var inputView: some View {
        VStack(spacing: 12) {
            HStack {
                TextField("Ask about your finances...", text: $queryText)
                    .textFieldStyle(.roundedBorder)
                    .onSubmit {
                        sendQuery()
                    }
                
                Button(action: sendQuery) {
                    Image(systemName: "paperplane.fill")
                        .foregroundColor(.white)
                        .frame(width: 36, height: 36)
                        .background(queryText.isEmpty ? Color.gray : Color.blue)
                        .clipShape(Circle())
                }
                .disabled(queryText.isEmpty || apiService.isLoading || !apiService.isConnected)
            }
            
            if !apiService.isConnected {
                Text("Connect to server to ask questions")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
        }
        .padding()
        .background(Color(.systemGray6))
    }
    
    // MARK: - Actions
    
    private func sendQuery() {
        guard !queryText.isEmpty else { return }
        
        let query = queryText
        queryText = ""
        
        Task {
            await apiService.askFinancialQuestion(query)
        }
    }
}

// MARK: - Preview

#Preview {
    AIFinancialAssistantView()
}