import SwiftUI
import SwiftData
import EventKit
import UserNotifications
import os.log

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
    @EnvironmentObject private var plaidService: PlaidService
    @Environment(\.modelContext) private var modelContext
    @State private var dataManager: DataManager?
    @State private var showPermissionSheet = false
    @State private var showModelContextError = false
    @State private var modelContextErrorMessage = ""
    
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
        Group {
            if let dataManager = dataManager {
                MainTabView()
                    .environmentObject(userManager)
                    .environmentObject(dataManager)
            } else {
                VStack {
                    ProgressView("Loading...")
                        .progressViewStyle(CircularProgressViewStyle())
                    Text("Initializing your budget data...")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                        .padding(.top, 8)
                }
            }
        }
        .sheet(isPresented: $showPermissionSheet) {
            PermissionRequestView()
                .environmentObject(permissionManager)
        }
        .onAppear {
            initializeDataManagers()
            // Check if permissions are needed after authentication
            if userManager.isAuthenticated && permissionManager.needsPermissions {
                showPermissionSheet = true
            }
        }
        .onChange(of: userManager.isAuthenticated) { _, isAuthenticated in
            if isAuthenticated {
                initializeDataManagers()
                // Show permission sheet if permissions are needed after authentication
                if permissionManager.needsPermissions {
                    showPermissionSheet = true
                }
            } else {
                dataManager = nil
            }
        }
    }
    
    // MARK: - Private Methods
    
    private func initializeDataManagers() {
        // Initialize data managers with the available modelContext
        if dataManager == nil {
            dataManager = DataManager(modelContext: modelContext)
            logger.info("DataManager initialized successfully")
        }
    }
}

// MARK: - Error Banner View

struct ErrorBannerView: View {
    let message: String
    let onDismiss: () -> Void
    
    var body: some View {
        HStack {
            Image(systemName: "exclamationmark.triangle.fill")
                .foregroundColor(.red)
            Text(message)
                .font(.subheadline)
                .foregroundColor(.primary)
            Spacer()
            Button("Dismiss") {
                onDismiss()
            }
            .font(.caption)
            .foregroundColor(.blue)
        }
        .padding()
        .background(Color.red.opacity(0.1))
        .overlay(
            RoundedRectangle(cornerRadius: 8)
                .stroke(Color.red.opacity(0.3), lineWidth: 1)
        )
        .clipShape(RoundedRectangle(cornerRadius: 8))
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
