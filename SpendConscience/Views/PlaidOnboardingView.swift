//
//  PlaidOnboardingView.swift
//  SpendConscience
//
//  Plaid integration onboarding flow using server-side backend
//

import SwiftUI

struct PlaidOnboardingView: View {
    @EnvironmentObject var plaidService: PlaidService
    @EnvironmentObject var dataManager: DataManager
    @Environment(\.dismiss) private var dismiss
    
    @State private var currentStep: OnboardingStep = .welcome
    @State private var isConnecting = false
    @State private var connectionError: String?
    @State private var showingError = false
    @State private var linkToken: String?
    
    enum OnboardingStep {
        case welcome
        case privacy
        case connecting
        case success
        case error
    }
    
    var body: some View {
        NavigationView {
            VStack(spacing: 0) {
                // Progress indicator
                progressIndicator
                
                // Content based on current step
                ScrollView {
                    VStack(spacing: 24) {
                        switch currentStep {
                        case .welcome:
                            welcomeStep
                        case .privacy:
                            privacyStep
                        case .connecting:
                            connectingStep
                        case .success:
                            successStep
                        case .error:
                            errorStep
                        }
                    }
                    .padding()
                }
                
                // Action buttons
                actionButtons
            }
            .navigationTitle("Connect Your Bank")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Cancel") {
                        dismiss()
                    }
                    .disabled(isConnecting)
                }
            }
        }
        .onAppear {
            // Check if already connected
            if plaidService.isPlaidLinked {
                currentStep = .success
            }
        }
        .alert("Connection Error", isPresented: $showingError) {
            Button("Try Again") {
                currentStep = .welcome
                connectionError = nil
            }
            Button("Cancel") {
                dismiss()
            }
        } message: {
            if let error = connectionError {
                Text(error)
            }
        }
    }
    
    // MARK: - Progress Indicator
    
    private var progressIndicator: some View {
        HStack(spacing: 8) {
            ForEach(0..<4, id: \.self) { index in
                Rectangle()
                    .fill(stepIndex >= index ? Color.accentColor : Color(.systemGray4))
                    .frame(height: 4)
                    .animation(.easeInOut, value: stepIndex)
            }
        }
        .padding(.horizontal)
        .padding(.top, 8)
    }
    
    private var stepIndex: Int {
        switch currentStep {
        case .welcome: return 0
        case .privacy: return 1
        case .connecting: return 2
        case .success, .error: return 3
        }
    }
    
    // MARK: - Welcome Step
    
    private var welcomeStep: some View {
        VStack(spacing: 24) {
            // Hero image
            Image(systemName: "building.columns.fill")
                .font(.system(size: 80))
                .foregroundColor(.blue)
                .padding(.top, 20)
            
            VStack(spacing: 16) {
                Text("Connect Your Bank Account")
                    .font(.title)
                    .fontWeight(.bold)
                    .multilineTextAlignment(.center)
                
                Text("Link your bank account to get personalized financial insights and real-time budgeting powered by AI.")
                    .font(.body)
                    .foregroundColor(.secondary)
                    .multilineTextAlignment(.center)
                    .lineLimit(nil)
            }
            
            // Benefits list
            VStack(alignment: .leading, spacing: 16) {
                benefitRow(icon: "shield.checkered", title: "Bank-level security", description: "Your data is encrypted and protected")
                benefitRow(icon: "brain", title: "AI-powered insights", description: "Get smart recommendations based on your spending")
                benefitRow(icon: "chart.line.uptrend.xyaxis", title: "Real-time tracking", description: "See your transactions and budgets update automatically")
            }
            .padding(.top, 20)
        }
    }
    
    private func benefitRow(icon: String, title: String, description: String) -> some View {
        HStack(alignment: .top, spacing: 12) {
            Image(systemName: icon)
                .font(.title3)
                .foregroundColor(.green)
                .frame(width: 24)
            
            VStack(alignment: .leading, spacing: 4) {
                Text(title)
                    .font(.headline)
                    .fontWeight(.medium)
                
                Text(description)
                    .font(.subheadline)
                    .foregroundColor(.secondary)
            }
            
            Spacer()
        }
    }
    
    // MARK: - Privacy Step
    
    private var privacyStep: some View {
        VStack(spacing: 24) {
            Image(systemName: "lock.shield.fill")
                .font(.system(size: 60))
                .foregroundColor(.green)
            
            VStack(spacing: 16) {
                Text("Your Privacy Matters")
                    .font(.title2)
                    .fontWeight(.bold)
                    .multilineTextAlignment(.center)
                
                Text("We use industry-standard security to protect your information.")
                    .font(.body)
                    .foregroundColor(.secondary)
                    .multilineTextAlignment(.center)
            }
            
            VStack(alignment: .leading, spacing: 16) {
                privacyRow(icon: "lock.fill", title: "Read-only access", description: "We can only view your transactions, never move money")
                privacyRow(icon: "eye.slash.fill", title: "No passwords stored", description: "Your banking passwords are never saved on our servers")
                privacyRow(icon: "server.rack", title: "Secure encryption", description: "All data is encrypted both in transit and at rest")
                privacyRow(icon: "hand.raised.fill", title: "You're in control", description: "Disconnect your account anytime from settings")
            }
            .padding(.top, 20)
        }
    }
    
    private func privacyRow(icon: String, title: String, description: String) -> some View {
        HStack(alignment: .top, spacing: 12) {
            Image(systemName: icon)
                .font(.title3)
                .foregroundColor(.blue)
                .frame(width: 24)
            
            VStack(alignment: .leading, spacing: 4) {
                Text(title)
                    .font(.headline)
                    .fontWeight(.medium)
                
                Text(description)
                    .font(.subheadline)
                    .foregroundColor(.secondary)
            }
            
            Spacer()
        }
    }
    
    // MARK: - Connecting Step
    
    private var connectingStep: some View {
        VStack(spacing: 32) {
            Spacer()
            
            VStack(spacing: 20) {
                ProgressView()
                    .scaleEffect(1.5)
                
                Text("Connecting to your bank...")
                    .font(.headline)
                
                Text("This may take a few moments")
                    .font(.subheadline)
                    .foregroundColor(.secondary)
            }
            
            Spacer()
            
            // Connection steps
            VStack(alignment: .leading, spacing: 12) {
                connectionStepRow(step: 1, title: "Securing connection", isActive: true)
                connectionStepRow(step: 2, title: "Authenticating with bank", isActive: false)
                connectionStepRow(step: 3, title: "Syncing account data", isActive: false)
            }
            .padding(.bottom, 40)
        }
    }
    
    private func connectionStepRow(step: Int, title: String, isActive: Bool) -> some View {
        HStack(spacing: 12) {
            ZStack {
                Circle()
                    .fill(isActive ? Color.blue : Color(.systemGray4))
                    .frame(width: 24, height: 24)
                
                Text("\(step)")
                    .font(.caption)
                    .fontWeight(.medium)
                    .foregroundColor(.white)
            }
            
            Text(title)
                .font(.subheadline)
                .foregroundColor(isActive ? .primary : .secondary)
            
            Spacer()
            
            if isActive {
                ProgressView()
                    .scaleEffect(0.8)
            }
        }
    }
    
    // MARK: - Success Step
    
    private var successStep: some View {
        VStack(spacing: 24) {
            Spacer()
            
            Image(systemName: "checkmark.circle.fill")
                .font(.system(size: 80))
                .foregroundColor(.green)
            
            VStack(spacing: 16) {
                Text("Successfully Connected!")
                    .font(.title)
                    .fontWeight(.bold)
                    .multilineTextAlignment(.center)
                
                Text("Your bank account is now linked. You'll start seeing AI-powered insights based on your spending patterns.")
                    .font(.body)
                    .foregroundColor(.secondary)
                    .multilineTextAlignment(.center)
                    .lineLimit(nil)
            }
            
            // Next steps
            VStack(alignment: .leading, spacing: 16) {
                nextStepRow(icon: "chart.pie.fill", title: "Check your budget dashboard", description: "See how you're doing this month")
                nextStepRow(icon: "brain.head.profile", title: "Ask the AI assistant", description: "Get personalized financial advice")
                nextStepRow(icon: "bell.fill", title: "Enable notifications", description: "Get alerts when you're near budget limits")
            }
            .padding(.top, 20)
            
            Spacer()
        }
    }
    
    private func nextStepRow(icon: String, title: String, description: String) -> some View {
        HStack(alignment: .top, spacing: 12) {
            Image(systemName: icon)
                .font(.title3)
                .foregroundColor(.blue)
                .frame(width: 24)
            
            VStack(alignment: .leading, spacing: 4) {
                Text(title)
                    .font(.headline)
                    .fontWeight(.medium)
                
                Text(description)
                    .font(.subheadline)
                    .foregroundColor(.secondary)
            }
            
            Spacer()
        }
    }
    
    // MARK: - Error Step
    
    private var errorStep: some View {
        VStack(spacing: 24) {
            Spacer()
            
            Image(systemName: "exclamationmark.triangle.fill")
                .font(.system(size: 60))
                .foregroundColor(.orange)
            
            VStack(spacing: 16) {
                Text("Connection Failed")
                    .font(.title2)
                    .fontWeight(.bold)
                
                if let error = connectionError {
                    Text(error)
                        .font(.body)
                        .foregroundColor(.secondary)
                        .multilineTextAlignment(.center)
                } else {
                    Text("We couldn't connect to your bank account. Please try again.")
                        .font(.body)
                        .foregroundColor(.secondary)
                        .multilineTextAlignment(.center)
                }
            }
            
            Spacer()
        }
    }
    
    // MARK: - Action Buttons
    
    private var actionButtons: some View {
        VStack(spacing: 12) {
            switch currentStep {
            case .welcome:
                Button(action: { currentStep = .privacy }) {
                    Text("Get Started")
                        .font(.headline)
                        .frame(maxWidth: .infinity)
                        .padding()
                        .background(Color.accentColor)
                        .foregroundColor(.white)
                        .cornerRadius(12)
                }
                
            case .privacy:
                Button(action: { startConnection() }) {
                    Text("I Understand, Connect My Bank")
                        .font(.headline)
                        .frame(maxWidth: .infinity)
                        .padding()
                        .background(Color.accentColor)
                        .foregroundColor(.white)
                        .cornerRadius(12)
                }
                
                Button(action: { currentStep = .welcome }) {
                    Text("Back")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                }
                
            case .connecting:
                // No buttons during connection
                EmptyView()
                
            case .success:
                Button(action: { dismiss() }) {
                    Text("Continue to App")
                        .font(.headline)
                        .frame(maxWidth: .infinity)
                        .padding()
                        .background(Color.accentColor)
                        .foregroundColor(.white)
                        .cornerRadius(12)
                }
                
            case .error:
                Button(action: { startConnection() }) {
                    Text("Try Again")
                        .font(.headline)
                        .frame(maxWidth: .infinity)
                        .padding()
                        .background(Color.accentColor)
                        .foregroundColor(.white)
                        .cornerRadius(12)
                }
                
                Button(action: { dismiss() }) {
                    Text("Skip for Now")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                }
            }
        }
        .padding()
        .disabled(isConnecting)
    }
    
    // MARK: - Connection Logic
    
    private func startConnection() {
        currentStep = .connecting
        isConnecting = true
        
        Task {
            do {
                // Step 1: Get link token from backend
                let linkTokenResponse = try await dataManager.apiService.createPlaidLinkToken()
                linkToken = linkTokenResponse.linkToken
                
                // In a real implementation with Plaid Link SDK:
                // 1. Initialize Plaid Link with the link token
                // 2. Present Plaid Link UI
                // 3. Handle the public token in the success callback
                // 4. Exchange public token for access token
                
                // For now, simulate the Plaid Link flow
                try await simulatePlaidLinkFlow()
                
                await MainActor.run {
                    isConnecting = false
                    currentStep = .success
                    plaidService.isPlaidLinked = true
                    plaidService.lastSyncDate = Date()
                }
            } catch {
                await MainActor.run {
                    isConnecting = false
                    connectionError = error.localizedDescription
                    currentStep = .error
                }
            }
        }
    }
    
    private func simulatePlaidLinkFlow() async throws {
        // Simulate user going through Plaid Link
        try await Task.sleep(nanoseconds: 2_000_000_000) // 2 seconds
        
        // Simulate getting a public token from Plaid Link
        let mockPublicToken = "public-sandbox-\(UUID().uuidString)"
        
        // Exchange the public token for an access token
        _ = try await dataManager.apiService.exchangePlaidPublicToken(publicToken: mockPublicToken)
        
        // Fetch accounts to populate the UI
        let accountsResponse = try await dataManager.apiService.fetchPlaidAccounts()
        
        await MainActor.run {
            // Update PlaidService with the connected accounts
            plaidService.linkedAccounts = accountsResponse.accounts.map { account in
                PlaidAccount(
                    id: account.id,
                    name: account.name,
                    type: mapAccountType(account.type),
                    subtype: mapAccountSubtype(account.subtype),
                    balance: AccountBalance(
                        available: account.balance.available,
                        current: account.balance.current,
                        limit: account.balance.limit,
                        isoCurrencyCode: account.balance.isoCurrencyCode,
                        unofficialCurrencyCode: nil
                    ),
                    mask: account.mask,
                    officialName: account.name
                )
            }
        }
    }
    
    // Helper functions to map account types
    private func mapAccountType(_ typeString: String) -> PlaidAccount.AccountType {
        switch typeString.lowercased() {
        case "depository": return .depository
        case "credit": return .credit
        case "loan": return .loan
        case "investment": return .investment
        case "other": return .other
        default: return .unknown(typeString)
        }
    }
    
    private func mapAccountSubtype(_ subtypeString: String?) -> PlaidAccount.AccountSubtype? {
        guard let subtypeString = subtypeString else { return nil }
        
        switch subtypeString.lowercased() {
        case "checking": return .checking
        case "savings": return .savings
        case "hsa": return .hsa
        case "cd": return .cd
        case "money market": return .moneyMarket
        case "paypal": return .paypal
        case "prepaid": return .prepaid
        case "cash management": return .cashManagement
        case "ebt": return .ebt
        case "credit card": return .creditCard
        default: return .unknown(subtypeString)
        }
    }
}

// MARK: - Preview

#Preview {
    PlaidOnboardingView()
        .environmentObject(PlaidService())
        .environmentObject(DataManager.preview())
}