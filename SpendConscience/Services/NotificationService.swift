//
//  NotificationService.swift
//  SpendConscience
//
//  Created by AI Assistant on 9/13/25.
//

import Foundation
import UserNotifications
import SwiftUI

/// Errors that can occur during notification operations
enum NotificationError: Error, LocalizedError {
    case permissionDenied
    case schedulingFailed(String)
    case invalidIdentifier
    case notificationCenterUnavailable
    case budgetMonitoringFailed(String)
    case budgetNotFound
    case thresholdDetectionFailed(String)
    
    var errorDescription: String? {
        switch self {
        case .permissionDenied:
            return "Notification permission denied"
        case .schedulingFailed(let reason):
            return "Failed to schedule notification: \(reason)"
        case .invalidIdentifier:
            return "Invalid notification identifier"
        case .notificationCenterUnavailable:
            return "Notification center unavailable"
        case .budgetMonitoringFailed(let reason):
            return "Budget monitoring failed: \(reason)"
        case .budgetNotFound:
            return "Budget not found for monitoring"
        case .thresholdDetectionFailed(let reason):
            return "Threshold detection failed: \(reason)"
        }
    }
}

/// Service class for managing local notifications
@MainActor
class NotificationService: ObservableObject {
    
    // MARK: - Properties
    
    /// Strong reference to the permission manager for authorization checks
    /// Using strong reference to ensure consistent permission logic throughout the service lifecycle
    private let permissionManager: PermissionManager?
    
    /// Published property to track notification permission status
    @Published var hasPermission: Bool = false
    
    /// Published property to track pending notifications count
    @Published var pendingNotificationsCount: Int = 0
    
    /// Published property to track which budgets are being monitored
    @Published var monitoredBudgets: Set<UUID> = []
    
    /// Track when notifications were last sent to prevent duplicates
    private var notificationHistory: [String: Date] = [:]
    
    /// Map to store last scheduled notification IDs for proper cancellation
    private var lastScheduledIds: [String: String] = [:]
    
    /// Set to track budgets currently being checked to prevent concurrent duplicate notifications
    private var inFlightChecks: Set<UUID> = []
    
    /// Minimum time between duplicate notifications (1 hour)
    private let duplicatePreventionInterval: TimeInterval = 3600
    
    /// Notification center instance
    private let notificationCenter = UNUserNotificationCenter.current()
    
    // MARK: - Notification Categories
    
    /// Notification category identifiers
    enum CategoryIdentifier: String, CaseIterable {
        case budgetAlert = "BUDGET_ALERT"
        case spendingReminder = "SPENDING_REMINDER"
        case weeklyReport = "WEEKLY_REPORT"
        
        var actions: [UNNotificationAction] {
            switch self {
            case .budgetAlert:
                return [
                    UNNotificationAction(identifier: "VIEW_BUDGET", title: "View Budget", options: [.foreground]),
                    UNNotificationAction(identifier: "DISMISS", title: "Dismiss", options: [])
                ]
            case .spendingReminder:
                return [
                    UNNotificationAction(identifier: "ADD_TRANSACTION", title: "Add Transaction", options: [.foreground]),
                    UNNotificationAction(identifier: "VIEW_SPENDING", title: "View Spending", options: [.foreground])
                ]
            case .weeklyReport:
                return [
                    UNNotificationAction(identifier: "VIEW_REPORT", title: "View Report", options: [.foreground])
                ]
            }
        }
    }
    
    // MARK: - Initialization
    
    init(permissionManager: PermissionManager? = nil) {
        self.permissionManager = permissionManager
        loadNotificationHistory()
        setupNotificationCategories()
        Task {
            await updatePermissionStatus()
            await updatePendingNotificationsCount()
        }
    }
    
    // MARK: - Permission Management
    
    /// Check current notification permission status
    func checkNotificationPermission() async -> Bool {
        guard let permissionManager = permissionManager else {
            // Fallback to direct check if permission manager is not available
            let settings = await notificationCenter.notificationSettings()
            return settings.authorizationStatus == .authorized || settings.authorizationStatus == .provisional
        }
        
        return permissionManager.hasNotificationPermission
    }
    
    /// Request notification permissions
    func requestNotificationPermission() async -> Bool {
        // Always request notification permission directly to avoid triggering calendar consent
        do {
            let granted = try await notificationCenter.requestAuthorization(options: [.alert, .badge, .sound])
            await updatePermissionStatus()
            return granted
        } catch {
            print("Failed to request notification permission: \(error)")
            return false
        }
    }
    
    /// Update the published permission status
    private func updatePermissionStatus() async {
        hasPermission = await checkNotificationPermission()
    }
    
    // MARK: - Notification Scheduling
    
    /// Schedule a local notification with specified parameters
    /// - Parameters:
    ///   - identifier: Unique identifier for the notification
    ///   - title: Notification title
    ///   - body: Notification body text
    ///   - timeInterval: Time interval in seconds from now when notification should fire
    ///   - categoryIdentifier: Optional category for the notification
    /// - Throws: NotificationError if scheduling fails
    func scheduleNotification(
        identifier: String,
        title: String,
        body: String,
        timeInterval: TimeInterval,
        categoryIdentifier: CategoryIdentifier? = nil
    ) async throws {
        
        // Validate inputs
        guard !identifier.isEmpty else {
            throw NotificationError.invalidIdentifier
        }
        
        // Validate timeInterval to avoid invalid trigger values
        guard timeInterval >= 1 else { 
            throw NotificationError.schedulingFailed("timeInterval must be >= 1 second") 
        }
        
        // Check permissions
        let hasPermission = await checkNotificationPermission()
        guard hasPermission else {
            throw NotificationError.permissionDenied
        }
        
        // Create notification content
        let content = UNMutableNotificationContent()
        content.title = title
        content.body = body
        content.sound = .default
        
        // Set category if provided
        if let categoryIdentifier = categoryIdentifier {
            content.categoryIdentifier = categoryIdentifier.rawValue
        }
        
        // Create trigger
        let trigger = UNTimeIntervalNotificationTrigger(timeInterval: timeInterval, repeats: false)
        
        // Create request
        let request = UNNotificationRequest(identifier: identifier, content: content, trigger: trigger)
        
        // Schedule notification
        do {
            try await notificationCenter.add(request)
            await updatePendingNotificationsCount()
            print("Notification scheduled successfully with identifier: \(identifier)")
        } catch {
            print("Failed to schedule notification: \(error)")
            throw NotificationError.schedulingFailed(error.localizedDescription)
        }
    }
    
    /// Schedule a repeating notification
    /// - Parameters:
    ///   - identifier: Unique identifier for the notification
    ///   - title: Notification title
    ///   - body: Notification body text
    ///   - dateComponents: Date components for when notification should repeat
    ///   - categoryIdentifier: Optional category for the notification
    /// - Throws: NotificationError if scheduling fails
    func scheduleRepeatingNotification(
        identifier: String,
        title: String,
        body: String,
        dateComponents: DateComponents,
        categoryIdentifier: CategoryIdentifier? = nil
    ) async throws {
        
        // Validate inputs
        guard !identifier.isEmpty else {
            throw NotificationError.invalidIdentifier
        }
        
        // Validate repeating DateComponents to avoid invalid or unintended schedules
        let calendar = Calendar.current
        guard calendar.date(from: dateComponents) != nil else {
            throw NotificationError.schedulingFailed("Invalid date components for repeating trigger")
        }
        
        // Check permissions
        let hasPermission = await checkNotificationPermission()
        guard hasPermission else {
            throw NotificationError.permissionDenied
        }
        
        // Create notification content
        let content = UNMutableNotificationContent()
        content.title = title
        content.body = body
        content.sound = .default
        
        // Set category if provided
        if let categoryIdentifier = categoryIdentifier {
            content.categoryIdentifier = categoryIdentifier.rawValue
        }
        
        // Create calendar trigger
        let trigger = UNCalendarNotificationTrigger(dateMatching: dateComponents, repeats: true)
        
        // Create request
        let request = UNNotificationRequest(identifier: identifier, content: content, trigger: trigger)
        
        // Schedule notification
        do {
            try await notificationCenter.add(request)
            await updatePendingNotificationsCount()
            print("Repeating notification scheduled successfully with identifier: \(identifier)")
        } catch {
            print("Failed to schedule repeating notification: \(error)")
            throw NotificationError.schedulingFailed(error.localizedDescription)
        }
    }
    
    // MARK: - Notification Management
    
    /// Cancel a specific notification by identifier
    /// - Parameter identifier: The identifier of the notification to cancel
    func cancelNotification(identifier: String) async {
        guard !identifier.isEmpty else {
            print("Cannot cancel notification: invalid identifier")
            return
        }
        
        notificationCenter.removePendingNotificationRequests(withIdentifiers: [identifier])
        await updatePendingNotificationsCount()
        print("Notification cancelled with identifier: \(identifier)")
    }
    
    /// Cancel all pending notifications
    func cancelAllNotifications() async {
        notificationCenter.removeAllPendingNotificationRequests()
        await updatePendingNotificationsCount()
        print("All notifications cancelled")
    }
    
    /// Get list of pending notifications
    /// - Returns: Array of pending notification requests
    func getPendingNotifications() async -> [UNNotificationRequest] {
        return await notificationCenter.pendingNotificationRequests()
    }
    
    /// Remove delivered notifications from notification center
    /// - Parameter identifiers: Array of notification identifiers to remove
    func removeDeliveredNotifications(identifiers: [String]) async {
        guard !identifiers.isEmpty else {
            print("No identifiers provided for removing delivered notifications")
            return
        }
        
        notificationCenter.removeDeliveredNotifications(withIdentifiers: identifiers)
        print("Removed delivered notifications with identifiers: \(identifiers)")
    }
    
    /// Remove all delivered notifications
    func removeAllDeliveredNotifications() async {
        notificationCenter.removeAllDeliveredNotifications()
        print("All delivered notifications removed")
    }
    
    /// Update the count of pending notifications
    private func updatePendingNotificationsCount() async {
        let pendingRequests = await getPendingNotifications()
        pendingNotificationsCount = pendingRequests.count
    }
    
    // MARK: - Notification Categories Setup
    
    /// Set up notification categories for interactive notifications
    private func setupNotificationCategories() {
        let categories = CategoryIdentifier.allCases.map { categoryId in
            UNNotificationCategory(
                identifier: categoryId.rawValue,
                actions: categoryId.actions,
                intentIdentifiers: [],
                options: []
            )
        }
        
        notificationCenter.setNotificationCategories(Set(categories))
        print("Notification categories set up successfully")
    }
    
    // MARK: - Utility Methods
    
    /// Check if a specific notification is pending
    /// - Parameter identifier: The identifier to check
    /// - Returns: True if notification is pending, false otherwise
    func isNotificationPending(identifier: String) async -> Bool {
        let pendingRequests = await getPendingNotifications()
        return pendingRequests.contains { $0.identifier == identifier }
    }
    
    /// Get notification settings
    /// - Returns: Current notification settings
    func getNotificationSettings() async -> UNNotificationSettings {
        return await notificationCenter.notificationSettings()
    }
    
    /// Log current notification status for debugging
    func logNotificationStatus() async {
        let settings = await getNotificationSettings()
        let pendingCount = await getPendingNotifications().count
        
        print("=== Notification Service Status ===")
        print("Authorization Status: \(settings.authorizationStatus.rawValue)")
        print("Alert Setting: \(settings.alertSetting.rawValue)")
        print("Badge Setting: \(settings.badgeSetting.rawValue)")
        print("Sound Setting: \(settings.soundSetting.rawValue)")
        print("Pending Notifications: \(pendingCount)")
        print("Has Permission: \(hasPermission)")
        print("==================================")
    }
    
    // MARK: - Budget Monitoring
    
    /// Start monitoring a budget for threshold breaches
    /// - Parameter budget: The budget to monitor
    func startMonitoringBudget(_ budget: Budget) async {
        do {
            monitoredBudgets.insert(budget.id)
            print("Started monitoring budget: \(budget.category.displayName) (ID: \(budget.id))")
            
            // Perform initial threshold check
            try await checkBudgetStatus(budget)
        } catch {
            print("Failed to start monitoring budget \(budget.category.displayName): \(error)")
        }
    }
    
    /// Stop monitoring a budget
    /// - Parameter budget: The budget to stop monitoring
    func stopMonitoringBudget(_ budget: Budget) async {
        monitoredBudgets.remove(budget.id)
        
        // Cancel any pending notifications for this budget using stored IDs
        let warningKey = "\(budget.id.uuidString)_warning"
        let overrunKey = "\(budget.id.uuidString)_overrun"
        
        if let warningId = lastScheduledIds[warningKey] {
            await cancelNotification(identifier: warningId)
            lastScheduledIds.removeValue(forKey: warningKey)
        }
        
        if let overrunId = lastScheduledIds[overrunKey] {
            await cancelNotification(identifier: overrunId)
            lastScheduledIds.removeValue(forKey: overrunKey)
        }
        
        // Clean up notification history
        notificationHistory.removeValue(forKey: warningKey)
        notificationHistory.removeValue(forKey: overrunKey)
        
        print("Stopped monitoring budget: \(budget.category.displayName) (ID: \(budget.id))")
    }
    
    /// Check budget status and trigger notifications if thresholds are breached
    /// - Parameter budget: The budget to check
    /// - Throws: NotificationError if checking fails
    func checkBudgetStatus(_ budget: Budget) async throws {
        guard monitoredBudgets.contains(budget.id) else {
            return // Budget is not being monitored
        }
        
        // Prevent concurrent checks for the same budget
        guard !inFlightChecks.contains(budget.id) else {
            return // Budget is already being checked
        }
        
        inFlightChecks.insert(budget.id)
        defer {
            inFlightChecks.remove(budget.id)
        }
        
        do {
            // Check for warning threshold (80% utilization)
            if shouldTriggerWarningNotification(for: budget) {
                try await scheduleWarningNotification(for: budget)
            }
            
            // Check for overrun threshold
            if shouldTriggerOverrunNotification(for: budget) {
                try await scheduleOverrunNotification(for: budget)
            }
            
            print("Budget status checked for: \(budget.category.displayName) - Utilization: \(Int(budget.utilizationPercentage))%")
        } catch {
            print("Failed to check budget status for \(budget.category.displayName): \(error)")
            throw NotificationError.thresholdDetectionFailed(error.localizedDescription)
        }
    }
    
    /// Check all monitored budgets for threshold breaches
    func checkAllMonitoredBudgets(fetch: (UUID) -> Budget?) async {
        print("Checking all monitored budgets (\(monitoredBudgets.count) budgets)")
        
        for budgetId in monitoredBudgets {
            guard let budget = fetch(budgetId) else {
                print("Could not fetch budget with ID: \(budgetId)")
                continue
            }
            
            do {
                try await checkBudgetStatus(budget)
            } catch {
                print("Failed to check budget status for \(budget.category.displayName): \(error)")
            }
        }
    }
    
    /// Public method to be called when budget spending changes
    /// - Parameter budget: The updated budget
    func onBudgetUpdated(_ budget: Budget) async {
        guard monitoredBudgets.contains(budget.id) else {
            return // Budget is not being monitored
        }
        
        do {
            try await checkBudgetStatus(budget)
        } catch {
            print("Failed to process budget update for \(budget.category.displayName): \(error)")
        }
    }
    
    // MARK: - Threshold Detection Logic
    
    /// Check if warning notification should be triggered
    /// - Parameter budget: The budget to check
    /// - Returns: True if warning notification should be sent
    private func shouldTriggerWarningNotification(for budget: Budget) -> Bool {
        // Check if budget utilization >= 80% and not over budget (to avoid duplicate overrun notifications)
        guard budget.isNearLimit && !budget.isOverBudget else {
            return false
        }
        
        // Check notification history to prevent duplicates
        let _ = "\(budget.id.uuidString)_warning"
        return !hasRecentNotification(for: budget, type: "warning")
    }
    
    /// Check if overrun notification should be triggered
    /// - Parameter budget: The budget to check
    /// - Returns: True if overrun notification should be sent
    private func shouldTriggerOverrunNotification(for budget: Budget) -> Bool {
        // Check if budget is over budget
        guard budget.isOverBudget else {
            return false
        }
        
        // Check notification history to prevent duplicates
        return !hasRecentNotification(for: budget, type: "overrun")
    }
    
    // MARK: - Notification Scheduling Integration
    
    /// Schedule warning notification for budget
    /// - Parameter budget: The budget to create warning notification for
    /// - Throws: NotificationError if scheduling fails
    private func scheduleWarningNotification(for budget: Budget) async throws {
        let template = NotificationTemplate.budgetWarningTemplate(for: budget)
        let id = template.generateIdentifier()
        let key = "\(budget.id.uuidString)_warning"
        
        do {
            try await template.scheduleNotification(using: self, overrideIdentifier: id)
            lastScheduledIds[key] = id
            updateNotificationHistory(for: budget, type: "warning")
            print("Warning notification scheduled for budget: \(budget.category.displayName)")
        } catch {
            print("Failed to schedule warning notification for budget \(budget.category.displayName): \(error)")
            throw NotificationError.schedulingFailed("Warning notification failed: \(error.localizedDescription)")
        }
    }
    
    /// Schedule overrun notification for budget
    /// - Parameter budget: The budget to create overrun notification for
    /// - Throws: NotificationError if scheduling fails
    private func scheduleOverrunNotification(for budget: Budget) async throws {
        let template = NotificationTemplate.budgetOverrunTemplate(for: budget)
        let id = template.generateIdentifier()
        let key = "\(budget.id.uuidString)_overrun"
        
        do {
            try await template.scheduleNotification(using: self, overrideIdentifier: id)
            lastScheduledIds[key] = id
            updateNotificationHistory(for: budget, type: "overrun")
            print("Overrun notification scheduled for budget: \(budget.category.displayName)")
        } catch {
            print("Failed to schedule overrun notification for budget \(budget.category.displayName): \(error)")
            throw NotificationError.schedulingFailed("Overrun notification failed: \(error.localizedDescription)")
        }
    }
    
    // MARK: - State Management Methods
    
    /// Update notification history for a budget
    /// - Parameters:
    ///   - budget: The budget
    ///   - type: The notification type ("warning" or "overrun")
    private func updateNotificationHistory(for budget: Budget, type: String) {
        let historyKey = "\(budget.id.uuidString)_\(type)"
        notificationHistory[historyKey] = Date()
        
        // Save to UserDefaults for persistence
        saveNotificationHistory()
        
        // Clean up old entries periodically
        if notificationHistory.count > 100 {
            cleanupNotificationHistory()
        }
    }
    
    /// Check if a recent notification was sent for a budget
    /// - Parameters:
    ///   - budget: The budget to check
    ///   - type: The notification type ("warning" or "overrun")
    /// - Returns: True if a recent notification was sent
    private func hasRecentNotification(for budget: Budget, type: String) -> Bool {
        let historyKey = "\(budget.id.uuidString)_\(type)"
        
        guard let lastNotificationDate = notificationHistory[historyKey] else {
            return false
        }
        
        let timeSinceLastNotification = Date().timeIntervalSince(lastNotificationDate)
        return timeSinceLastNotification < duplicatePreventionInterval
    }
    
    /// Clean up old notification history entries
    private func cleanupNotificationHistory() {
        let cutoffDate = Date().addingTimeInterval(-86400) // 24 hours ago
        
        notificationHistory = notificationHistory.filter { _, date in
            date > cutoffDate
        }
        
        // Save cleaned up history to UserDefaults
        saveNotificationHistory()
        
        print("Cleaned up notification history. Remaining entries: \(notificationHistory.count)")
    }
    
    // MARK: - Persistence Methods
    
    /// Load notification history from UserDefaults
    private func loadNotificationHistory() {
        guard let data = UserDefaults.standard.data(forKey: "NotificationHistory"),
              let decoded = try? JSONDecoder().decode([String: Date].self, from: data) else {
            print("No notification history found in UserDefaults")
            return
        }
        
        notificationHistory = decoded
        print("Loaded notification history with \(notificationHistory.count) entries")
        
        // Clean up old entries on load
        if !notificationHistory.isEmpty {
            cleanupNotificationHistory()
        }
    }
    
    /// Save notification history to UserDefaults
    private func saveNotificationHistory() {
        guard let encoded = try? JSONEncoder().encode(notificationHistory) else {
            print("Failed to encode notification history")
            return
        }
        
        UserDefaults.standard.set(encoded, forKey: "NotificationHistory")
        print("Saved notification history with \(notificationHistory.count) entries")
    }
    
    // MARK: - Convenience Methods
    
    /// Start monitoring multiple budgets
    /// - Parameter budgets: Array of budgets to monitor
    func startMonitoringAllBudgets(_ budgets: [Budget]) async {
        print("Starting monitoring for \(budgets.count) budgets")
        
        for budget in budgets {
            await startMonitoringBudget(budget)
        }
    }
    
    /// Get monitoring status for all budgets
    /// - Returns: Dictionary of budget IDs and their monitoring status
    func getMonitoringStatus() -> [UUID: Bool] {
        var status: [UUID: Bool] = [:]
        
        for budgetId in monitoredBudgets {
            status[budgetId] = true
        }
        
        return status
    }
    
    /// Log budget monitoring status for debugging
    func logBudgetMonitoringStatus() async {
        print("=== Budget Monitoring Status ===")
        print("Monitored Budgets: \(monitoredBudgets.count)")
        print("Budget IDs: \(monitoredBudgets.map { $0.uuidString })")
        print("Notification History Entries: \(notificationHistory.count)")
        print("Recent Notifications:")
        
        for (key, date) in notificationHistory.sorted(by: { $0.value > $1.value }).prefix(5) {
            let timeAgo = Date().timeIntervalSince(date)
            print("  \(key): \(Int(timeAgo/60)) minutes ago")
        }
        
        let pendingCount = await getPendingNotifications().count
        print("Pending Notifications: \(pendingCount)")
        print("===============================")
    }
    
    // MARK: - Private Helper Methods
    
    /// Sanitize identifier strings to remove special characters that could cause issues
    /// - Parameter input: The input string to sanitize
    /// - Returns: A sanitized string safe for use as notification identifier
    private func sanitizeIdentifier(_ input: String) -> String {
        // Remove non-alphanumeric characters and replace with underscores
        let sanitized = input.replacingOccurrences(of: "[^a-zA-Z0-9]", with: "_", options: .regularExpression)
        
        // Remove consecutive underscores and trim
        let cleaned = sanitized.replacingOccurrences(of: "_+", with: "_", options: .regularExpression)
            .trimmingCharacters(in: CharacterSet(charactersIn: "_"))
        
        // Ensure we have a valid identifier (fallback to hash if empty)
        if cleaned.isEmpty {
            return "budget_\(abs(input.hashValue))"
        }
        
        return cleaned
    }
}

// MARK: - Convenience Extensions

extension NotificationService {
    
    /// Schedule a budget alert notification
    /// - Parameters:
    ///   - budgetName: Name of the budget
    ///   - utilizationPercentage: Current utilization percentage
    ///   - timeInterval: When to show the notification
    func scheduleBudgetAlert(budgetName: String, utilizationPercentage: Double, timeInterval: TimeInterval = 1) async throws {
        let sanitizedBudgetName = sanitizeIdentifier(budgetName)
        let identifier = "budget_alert_\(sanitizedBudgetName)_\(Date().timeIntervalSince1970)"
        let title = "Budget Alert"
        let body = "\(budgetName) budget is \(Int(utilizationPercentage))% utilized"
        
        try await scheduleNotification(
            identifier: identifier,
            title: title,
            body: body,
            timeInterval: timeInterval,
            categoryIdentifier: .budgetAlert
        )
    }
    
    /// Schedule a spending reminder notification
    /// - Parameters:
    ///   - message: Custom reminder message
    ///   - timeInterval: When to show the notification
    func scheduleSpendingReminder(message: String, timeInterval: TimeInterval = 1) async throws {
        let identifier = "spending_reminder_\(Date().timeIntervalSince1970)"
        let title = "Spending Reminder"
        let body = message
        
        try await scheduleNotification(
            identifier: identifier,
            title: title,
            body: body,
            timeInterval: timeInterval,
            categoryIdentifier: .spendingReminder
        )
    }
    
    /// Schedule a weekly report notification
    /// - Parameters:
    ///   - totalSpent: Total amount spent this week
    ///   - dateComponents: When to repeat the notification
    func scheduleWeeklyReport(totalSpent: Double, dateComponents: DateComponents) async throws {
        let identifier = "weekly_report"
        let title = "Weekly Spending Report"
        let body = "You spent $\(String(format: "%.2f", totalSpent)) this week"
        
        // Cancel any existing weekly report notification before scheduling a new one
        // This prevents unintentional replacement of existing schedules
        await cancelNotification(identifier: identifier)
        
        try await scheduleRepeatingNotification(
            identifier: identifier,
            title: title,
            body: body,
            dateComponents: dateComponents,
            categoryIdentifier: .weeklyReport
        )
    }
}
