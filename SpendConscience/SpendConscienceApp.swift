import SwiftUI
import UserNotifications
import EventKit

@main
struct SpendConscienceApp: App {
    var body: some Scene {
        WindowGroup {
            ContentView()
                .onAppear {
                    requestPermissions()
                }
        }
    }
    
    private func requestPermissions() {
        // Request notification permissions
        UNUserNotificationCenter.current().requestAuthorization(options: [.alert, .badge, .sound]) { _, _ in }
        
        // Request calendar permissions
        let eventStore = EKEventStore()
        eventStore.requestAccess(to: .event) { _, _ in }
    }
}