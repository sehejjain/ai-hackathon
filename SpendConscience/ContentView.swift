import SwiftUI
import SwiftData
import EventKit
import UserNotifications
import os.log

// MARK: - Navigation Destination Enum

fileprivate enum Destination {
    case budgetDashboard
}

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
    @EnvironmentObject private var userManager: UserManager
    @Environment(\.modelContext) private var modelContext
    @State private var dataManager: DataManager?
    @State private var showPermissionSheet = false
    @State private var showAIAssistant = false
    @State private var navigationPath = NavigationPath()
    
    // App-level dark mode control
    @AppStorage("darkModeEnabled") var darkModeEnabled = false

    private let logger = Logger(subsystem: "SpendConscience", category: "ContentView")
    
    var body: some View {
        Group {
            if !userManager.isAuthenticated {
                AuthenticationView()
            } else {
                authenticatedView
            }
        }
        .preferredColorScheme(darkModeEnabled ? .dark : .light)
    }
    
    private var authenticatedView: some View {
        NavigationStack(path: $navigationPath) {
            if let dataManager = dataManager {
                MainTabView()
                    .environmentObject(userManager)
                    .environmentObject(dataManager)
            } else {
                VStack(spacing: 24) {
                    Text("SpendConscience")
                        .font(.largeTitle)
                        .fontWeight(.bold)

                    Text("Your AI Financial Assistant")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                        .multilineTextAlignment(.center)

                    Spacer()

                    Button("Get Started") {
                        if permissionManager.needsPermissions {
                            showPermissionSheet = true
                        }
                    }
                    .buttonStyle(.borderedProminent)
                    .controlSize(.large)

                    Spacer()
                }
            }
        }
        .padding()
        .navigationTitle("Budget Overview")
        .navigationBarTitleDisplayMode(.inline)
        .sheet(isPresented: $showPermissionSheet) {
            PermissionRequestView()
                .environmentObject(permissionManager)
        }
        .sheet(isPresented: $showAIAssistant) {
            if let dataManager = dataManager {
                AIFinancialAssistantView()
                    .environmentObject(userManager)
                    .environmentObject(dataManager)
            }
        }
        .navigationDestination(for: Destination.self) { destination in
            switch destination {
            case .budgetDashboard:
                if let dataManager = dataManager {
                    BudgetDashboardView()
                        .environmentObject(dataManager)
                } else {
                    Text("Loading...")
                        .navigationTitle("Budget Dashboard")
                }
            }
        }
        .onAppear {
            if userManager.isAuthenticated && dataManager == nil {
                initializeDataManager()
            }
            if permissionManager.needsPermissions {
                showPermissionSheet = true
            }
        }
        .onChange(of: userManager.isAuthenticated) { _, isAuthenticated in
            if isAuthenticated {
                initializeDataManager()
                if permissionManager.needsPermissions {
                    showPermissionSheet = true
                }
            } else {
                dataManager = nil
            }
        }
    }
    
    // MARK: - Private Methods
    
    private func initializeDataManager() {
        if dataManager == nil {
            dataManager = DataManager(modelContext: modelContext)
            logger.info("DataManager initialized successfully")
        }
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


#Preview {
    ContentView()
        .environmentObject(PermissionManager())
}
