import SwiftUI
import SwiftData
import EventKit
import UserNotifications

// MARK: - Permission Status Enum

enum PermissionStatus {
    case notification(UNAuthorizationStatus)
    case calendar(EKAuthorizationStatus)
    
    var isGranted: Bool {
        switch self {
        case .notification(let status):
            return status == .authorized || status == .provisional
        case .calendar(let status):
            if #available(iOS 17.0, *) {
                return status == .fullAccess || status == .writeOnly
            } else {
                return status == .authorized
            }
        }
    }
}

struct ContentView: View {
    @EnvironmentObject private var permissionManager: PermissionManager
    @EnvironmentObject private var plaidService: PlaidService
    @Environment(\.modelContext) private var modelContext
    @State private var dataManager: DataManager?
    @State private var transactionStore: TransactionStore?
    @State private var showPermissionSheet = false
    @State private var showTransactionList = false
    
    var body: some View {
        NavigationView {
            VStack(spacing: 30) {
                VStack {
                    Text("SpendConscience")
                        .font(.largeTitle)
                        .fontWeight(.bold)
                    
                    Text("Your Autonomous Budgeting Agent")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                        .multilineTextAlignment(.center)
                }
                
                // Permission status indicator
                if permissionManager.needsPermissions {
                    PermissionStatusView(showPermissionSheet: $showPermissionSheet)
                }
                
                Spacer()
                
                VStack(spacing: 16) {
                    Button("Get Started") {
                        if permissionManager.needsPermissions {
                            showPermissionSheet = true
                        } else {
                            // Navigation to onboarding
                        }
                    }
                    .buttonStyle(.borderedProminent)
                    .controlSize(.large)
                    
                    Button("View Budget") {
                        // Navigation to budget view
                    }
                    .buttonStyle(.bordered)
                    .controlSize(.large)
                    .disabled(permissionManager.needsPermissions)
                    
                    // Plaid Testing Interface
                    if let transactionStore = transactionStore {
                        PlaidTestingView(showTransactionList: $showTransactionList)
                            .environmentObject(plaidService)
                            .environmentObject(transactionStore)
                    }
                }
                
                Spacer()
            }
            .padding()
            .navigationTitle("Budget Overview")
            .navigationBarTitleDisplayMode(.inline)
            .sheet(isPresented: $showPermissionSheet) {
                PermissionRequestView()
                    .environmentObject(permissionManager)
            }
            .sheet(isPresented: $showTransactionList) {
                if let transactionStore = transactionStore {
                    TransactionListView()
                        .environmentObject(plaidService)
                        .environmentObject(transactionStore)
                }
            }
            .onAppear {
                if dataManager == nil {
                    dataManager = DataManager(modelContext: modelContext)
                }
                if transactionStore == nil {
                    transactionStore = TransactionStore(modelContext: modelContext)
                }
            }
        }
    }
}

// MARK: - Permission Status View

struct PermissionStatusView: View {
    @EnvironmentObject private var permissionManager: PermissionManager
    @Binding var showPermissionSheet: Bool
    
    var body: some View {
        VStack(spacing: 12) {
            HStack {
                Image(systemName: "exclamationmark.triangle.fill")
                    .foregroundColor(.orange)
                Text("Permissions Required")
                    .font(.headline)
                Spacer()
            }
            
            Text("SpendConscience needs access to your calendar and notifications to provide proactive budget guidance and spending alerts.")
                .font(.subheadline)
                .foregroundColor(.secondary)
                .multilineTextAlignment(.leading)
            
            Button("Grant Permissions") {
                showPermissionSheet = true
            }
            .buttonStyle(.bordered)
            .controlSize(.small)
        }
        .padding()
        .background(Color(.systemBackground))
        .overlay(
            RoundedRectangle(cornerRadius: 12)
                .stroke(Color.orange.opacity(0.3), lineWidth: 1)
        )
        .clipShape(RoundedRectangle(cornerRadius: 12))
    }
}

// MARK: - Permission Request Sheet

struct PermissionRequestView: View {
    @EnvironmentObject private var permissionManager: PermissionManager
    @Environment(\.dismiss) private var dismiss
    @State private var isRequesting = false
    
    var body: some View {
        NavigationView {
            VStack(spacing: 24) {
                VStack(spacing: 16) {
                    Image(systemName: "shield.checkered")
                        .font(.system(size: 60))
                        .foregroundColor(.blue)
                    
                    Text("Enable Smart Budget Features")
                        .font(.title2)
                        .fontWeight(.semibold)
                        .multilineTextAlignment(.center)
                    
                    Text("To provide the best budgeting experience, SpendConscience needs access to:")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                        .multilineTextAlignment(.center)
                }
                
                VStack(spacing: 16) {
                    PermissionItemView(
                        icon: "calendar",
                        title: "Calendar Access",
                        description: "Create budget reminders and analyze upcoming events for better spending predictions",
                        status: .calendar(permissionManager.calendarStatus)
                    )
                    
                    PermissionItemView(
                        icon: "bell",
                        title: "Notifications",
                        description: "Receive timely alerts about budget limits and spending recommendations",
                        status: .notification(permissionManager.notificationStatus)
                    )
                }
                
                Spacer()
                
                VStack(spacing: 12) {
                    Button(action: requestPermissions) {
                        HStack {
                            if isRequesting {
                                ProgressView()
                                    .progressViewStyle(CircularProgressViewStyle(tint: .white))
                                    .scaleEffect(0.8)
                            }
                            Text(isRequesting ? "Requesting..." : "Grant Permissions")
                        }
                    }
                    .buttonStyle(.borderedProminent)
                    .controlSize(.large)
                    .disabled(isRequesting)
                    
                    Button("Maybe Later") {
                        dismiss()
                    }
                    .buttonStyle(.plain)
                    .foregroundColor(.secondary)
                }
            }
            .padding()
            .navigationTitle("Permissions")
            .navigationBarTitleDisplayMode(.inline)
            .navigationBarBackButtonHidden(true)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Skip") {
                        dismiss()
                    }
                }
            }
        }
    }
    
    private func requestPermissions() {
        isRequesting = true
        Task {
            await permissionManager.requestPermissions()
            await MainActor.run {
                isRequesting = false
                dismiss()
            }
        }
    }
}

// MARK: - Permission Item View

struct PermissionItemView: View {
    let icon: String
    let title: String
    let description: String
    let status: PermissionStatus
    
    var body: some View {
        HStack(spacing: 16) {
            Image(systemName: icon)
                .font(.title2)
                .foregroundColor(.blue)
                .frame(width: 30)
            
            VStack(alignment: .leading, spacing: 4) {
                Text(title)
                    .font(.headline)
                Text(description)
                    .font(.caption)
                    .foregroundColor(.secondary)
                    .multilineTextAlignment(.leading)
            }
            
            Spacer()
            
            Image(systemName: status.isGranted ? "checkmark.circle.fill" : "circle")
                .foregroundColor(status.isGranted ? .green : .gray)
        }
        .padding()
        .background(Color(.systemGray6))
        .clipShape(RoundedRectangle(cornerRadius: 12))
    }
}

// MARK: - Plaid Testing View

struct PlaidTestingView: View {
    @EnvironmentObject private var plaidService: PlaidService
    @Binding var showTransactionList: Bool
    
    var body: some View {
        VStack(spacing: 12) {
            // Service Status
            HStack {
                Image(systemName: "creditcard.fill")
                    .foregroundColor(.blue)
                Text("Plaid Integration")
                    .font(.headline)
                Spacer()
                
                if plaidService.isLoading {
                    ProgressView()
                        .scaleEffect(0.8)
                } else {
                    Image(systemName: plaidService.isConnected ? "checkmark.circle.fill" : "circle")
                        .foregroundColor(plaidService.isConnected ? .green : .gray)
                }
            }
            
            // Connection Info
            if plaidService.isConnected {
                VStack(alignment: .leading, spacing: 4) {
                    Text("Connected • \(plaidService.accounts.count) accounts • \(plaidService.transactions.count) transactions")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
            }
            
            // Error Display
            if let error = plaidService.currentError {
                Text("Error: \(error.localizedDescription)")
                    .font(.caption)
                    .foregroundColor(.red)
                    .multilineTextAlignment(.leading)
            }
            
            // Action Buttons
            HStack(spacing: 12) {
                Button("Test Connection") {
                    Task {
                        await plaidService.initializePlaidConnection()
                    }
                }
                .buttonStyle(.bordered)
                .controlSize(.small)
                .disabled(plaidService.isLoading)
                
                Button("Refresh Data") {
                    Task {
                        await plaidService.refreshData()
                    }
                }
                .buttonStyle(.bordered)
                .controlSize(.small)
                .disabled(!plaidService.isConnected || plaidService.isLoading)
                
                if !plaidService.transactions.isEmpty {
                    Button("View Transactions") {
                        showTransactionList = true
                    }
                    .buttonStyle(.borderedProminent)
                    .controlSize(.small)
                }
            }
        }
        .padding()
        .background(Color(.systemGray6))
        .clipShape(RoundedRectangle(cornerRadius: 12))
    }
}

#Preview {
    ContentView()
        .environmentObject(PermissionManager())
}
