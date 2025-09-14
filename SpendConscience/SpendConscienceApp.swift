import SwiftUI
import SwiftData
import UserNotifications
import EventKit

@main
struct SpendConscienceApp: App {
    @AppStorage("permissionsChecked") private var permissionsChecked = false
    @StateObject private var permissionManager = PermissionManager()
    @StateObject private var userManager = UserManager()
    @StateObject private var plaidService = PlaidService()
    
    // Single persistent ModelContainer instance
    private let modelContainer: ModelContainer
    
    init() {
        do {
            let container = try ModelContainer(for: Transaction.self, Budget.self, User.self)
            self.modelContainer = container
        } catch {
            print("Failed to initialize ModelContainer: \(error)")

            // Log detailed error for debugging
            if let detailedError = error as? CocoaError {
                print("CoreData Error Code: \(detailedError.code)")
                print("CoreData Error Description: \(detailedError.localizedDescription)")
            }

            // Attempt to create a temporary container as fallback
            do {
                let tempContainer = try ModelContainer(
                    for: Transaction.self, Budget.self, User.self,
                    configurations: ModelConfiguration(isStoredInMemoryOnly: true)
                )
                print("Created temporary in-memory container as fallback")
                self.modelContainer = tempContainer
            } catch {
                print("Failed to create fallback container: \(error)")

                // Last resort: create minimal container
                fatalError("Unable to initialize any ModelContainer. Please check your data model and try reinstalling the app.")
            }
        }
    }
    
    var body: some Scene {
        WindowGroup {
            ContentView()
                .environmentObject(permissionManager)
                .environmentObject(userManager)
                .environmentObject(plaidService)
                .onAppear {
                    if !permissionsChecked {
                        checkPermissionStatuses()
                        permissionsChecked = true
                    }
                    
                    // Set model context for user manager using the same persistent instance
                    userManager.setModelContext(modelContainer.mainContext)
                }
        }
        .modelContainer(modelContainer)
    }
    
    // MARK: - Permission Status Checking (No Prompts)
    
    private func checkPermissionStatuses() {
        Task {
            await permissionManager.checkAllPermissionStatuses()
        }
    }
}

// MARK: - Permission Manager

@MainActor
class PermissionManager: ObservableObject {
    @Published var notificationStatus: UNAuthorizationStatus = .notDetermined
    @Published var calendarStatus: EKAuthorizationStatus = .notDetermined
    
    private let eventStore = EKEventStore()
    
    /// Check current permission statuses without prompting user
    func checkAllPermissionStatuses() async {
        // Check notification status
        let notificationSettings = await UNUserNotificationCenter.current().notificationSettings()
        notificationStatus = notificationSettings.authorizationStatus
        
        // Check calendar status
        if #available(iOS 17.0, *) {
            calendarStatus = EKEventStore.authorizationStatus(for: .event)
        } else {
            calendarStatus = EKEventStore.authorizationStatus(for: .event)
        }
        
        print("Permission Status Check - Notifications: \(notificationStatus.rawValue), Calendar: \(calendarStatus.rawValue)")
    }
    
    /// Request permissions only when explicitly called by user action
    func requestPermissions() async {
        // Request notification permissions
        do {
            let granted = try await UNUserNotificationCenter.current().requestAuthorization(options: [.alert, .badge, .sound])
            print("Notification permission granted: \(granted)")
            await checkAllPermissionStatuses() // Refresh status
        } catch {
            print("Notification permission error: \(error)")
        }
        
        // Request calendar permissions
        await requestCalendarPermissions()
    }
    
    private func requestCalendarPermissions() async {
        if #available(iOS 17.0, *) {
            // iOS 17+: Use write-only access for budget planning and reminders
            do {
                let writeAccess = try await eventStore.requestWriteOnlyAccessToEvents()
                print("Calendar write-only access granted: \(writeAccess)")
                await checkAllPermissionStatuses() // Refresh status
                
                // If we need to read existing events for budget analysis, request full access
                // Uncomment the following lines if read access is essential:
                /*
                if writeAccess {
                    let fullAccess = try await eventStore.requestFullAccessToEvents()
                    print("Calendar full access granted: \(fullAccess)")
                    await checkAllPermissionStatuses()
                }
                */
            } catch {
                print("Calendar permission error: \(error)")
            }
        } else {
            // iOS 16 and earlier: Use traditional requestAccess method
            eventStore.requestAccess(to: .event) { [weak self] granted, error in
                Task { @MainActor in
                    if let error = error {
                        print("Calendar permission error: \(error)")
                    } else {
                        print("Calendar access granted: \(granted)")
                    }
                    await self?.checkAllPermissionStatuses() // Refresh status
                }
            }
        }
    }
    
    // MARK: - Permission Status Helpers
    
    var hasNotificationPermission: Bool {
        notificationStatus == .authorized || notificationStatus == .provisional
    }
    
    var hasCalendarPermission: Bool {
        if #available(iOS 17.0, *) {
            return calendarStatus == .fullAccess || calendarStatus == .writeOnly
        } else {
            return calendarStatus == .authorized
        }
    }
    
    var needsPermissions: Bool {
        !hasNotificationPermission || !hasCalendarPermission
    }
}
