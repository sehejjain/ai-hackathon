//
//  CalendarService.swift
//  SpendConscience
//
//  Service for fetching calendar events for AI analysis
//

import Foundation
import EventKit
import OSLog

/// Service for fetching and analyzing calendar events
@MainActor
class CalendarService: ObservableObject {

    // MARK: - Private Properties

    private let eventStore: EKEventStore
    private let logger = Logger(subsystem: "SpendConscience", category: "CalendarService")

    // MARK: - Initialization

    init(eventStore: EKEventStore = EKEventStore()) {
        self.eventStore = eventStore
    }

    // MARK: - Public Methods

    /// Fetches calendar events for the remaining days of the current month
    /// - Returns: Array of CalendarEventData for AI analysis
    func fetchRemainingMonthEvents() async -> [CalendarEventData] {
        logger.debug("🗓️ [CalendarService] Starting fetchRemainingMonthEvents")
        print("🗓️ [CalendarService] Starting fetchRemainingMonthEvents")

        // Check calendar permission
        let authStatus = EKEventStore.authorizationStatus(for: .event)
        logger.debug("🔐 [CalendarService] Calendar permission status: \(authStatus.rawValue)")
        print("🔐 [CalendarService] Calendar permission status: \(authStatus.rawValue)")

        guard hasValidCalendarPermission(authStatus) else {
            logger.warning("❌ [CalendarService] Calendar access not granted. Status: \(authStatus.rawValue)")
            print("❌ [CalendarService] Calendar access not granted. Status: \(authStatus.rawValue)")
            return []
        }

        logger.debug("✅ [CalendarService] Calendar permission validated")
        print("✅ [CalendarService] Calendar permission validated")

        // Calculate date range: today through last day of current month
        let calendar = Calendar.current
        let today = Date()
        let startOfToday = calendar.startOfDay(for: today)

        logger.debug("📅 [CalendarService] Today: \(today.description)")
        print("📅 [CalendarService] Today: \(today)")
        logger.debug("📅 [CalendarService] Start of today: \(startOfToday.description)")
        print("📅 [CalendarService] Start of today: \(startOfToday)")

        guard let endOfMonth = calendar.dateInterval(of: .month, for: today)?.end else {
            logger.error("❌ [CalendarService] Failed to get end of current month")
            print("❌ [CalendarService] Failed to get end of current month")
            return []
        }

        logger.debug("📅 [CalendarService] End of month: \(endOfMonth.description)")
        print("📅 [CalendarService] End of month: \(endOfMonth)")
        logger.debug("🔍 [CalendarService] Searching events from \(startOfToday.description) to \(endOfMonth.description)")
        print("🔍 [CalendarService] Searching events from \(startOfToday) to \(endOfMonth)")

        // Create predicate for the date range
        let predicate = eventStore.predicateForEvents(
            withStart: startOfToday,
            end: endOfMonth,
            calendars: nil
        )

        logger.debug("🔍 [CalendarService] Created predicate for date range")
        print("🔍 [CalendarService] Created predicate for date range")

        // Fetch events
        let ekEvents = eventStore.events(matching: predicate)

        logger.debug("📊 [CalendarService] Found \(ekEvents.count) raw EKEvents")
        print("📊 [CalendarService] Found \(ekEvents.count) raw EKEvents")

        // Log all raw events for debugging
        for (index, event) in ekEvents.enumerated() {
            let title = event.title ?? "No Title"
            let start = event.startDate.description
            let isAllDay = event.isAllDay
            logger.debug("📝 [CalendarService] Raw Event \(index + 1): '\(title)' at \(start), allDay: \(isAllDay)")
            print("📝 [CalendarService] Raw Event \(index + 1): '\(title)' at \(start), allDay: \(isAllDay)")
        }

        // Convert to CalendarEventData and filter relevant events
        var filteredCount = 0
        let calendarEvents = ekEvents.compactMap { ekEvent -> CalendarEventData? in
            let eventTitle = ekEvent.title ?? "No Title"

            // Skip all-day events that are likely not cost-related
            if ekEvent.isAllDay {
                logger.debug("⏭️ [CalendarService] Skipping all-day event: '\(eventTitle)'")
                print("⏭️ [CalendarService] Skipping all-day event: '\(eventTitle)'")
                filteredCount += 1
                return nil
            }

            // Skip events that are clearly work/system related
            let title = ekEvent.title?.lowercased() ?? ""
            if title.contains("work") || title.contains("meeting") || title.contains("call") ||
               title.contains("sync") || title.contains("standup") || title.contains("review") {
                logger.debug("⏭️ [CalendarService] Skipping work-related event: '\(eventTitle)'")
                print("⏭️ [CalendarService] Skipping work-related event: '\(eventTitle)'")
                filteredCount += 1
                return nil
            }

            // Skip events without a title
            guard let validTitle = ekEvent.title, !validTitle.isEmpty else {
                logger.debug("⏭️ [CalendarService] Skipping event without title")
                print("⏭️ [CalendarService] Skipping event without title")
                filteredCount += 1
                return nil
            }

            logger.debug("✅ [CalendarService] Including event: '\(validTitle)'")
            print("✅ [CalendarService] Including event: '\(validTitle)'")
            return CalendarEventData(from: ekEvent)
        }

        logger.info("📊 [CalendarService] Found \(calendarEvents.count) relevant calendar events for AI analysis (filtered out \(filteredCount))")
        print("📊 [CalendarService] Found \(calendarEvents.count) relevant calendar events for AI analysis (filtered out \(filteredCount))")

        // Log final events for debugging
        for (index, event) in calendarEvents.enumerated() {
            logger.debug("📝 [CalendarService] Final Event \(index + 1): '\(event.title)' - \(event.eventType.rawValue) - Est: $\(String(format: "%.2f", event.estimatedCost ?? 0))")
            print("📝 [CalendarService] Final Event \(index + 1): '\(event.title)' - \(event.eventType.rawValue) - Est: $\(String(format: "%.2f", event.estimatedCost ?? 0))")
        }

        let sortedEvents = calendarEvents.sorted { $0.startDate < $1.startDate }
        logger.debug("🏁 [CalendarService] Returning \(sortedEvents.count) events")
        print("🏁 [CalendarService] Returning \(sortedEvents.count) events")

        return sortedEvents
    }

    /// Calculates total estimated costs for upcoming events
    /// - Parameter events: Array of calendar events
    /// - Returns: Total estimated cost
    func calculateTotalEstimatedCosts(for events: [CalendarEventData]) -> Double {
        return events.compactMap { $0.estimatedCost }.reduce(0, +)
    }

    /// Groups events by type for analysis
    /// - Parameter events: Array of calendar events
    /// - Returns: Dictionary grouped by event type
    func groupEventsByType(_ events: [CalendarEventData]) -> [CalendarEventData.EventType: [CalendarEventData]] {
        return Dictionary(grouping: events) { $0.eventType }
    }

    /// Gets a summary of upcoming events for AI context
    /// - Parameter events: Array of calendar events
    /// - Returns: Human-readable summary string
    func getEventsSummary(for events: [CalendarEventData]) -> String {
        guard !events.isEmpty else {
            return "No upcoming events found for the rest of the month."
        }

        let totalCost = calculateTotalEstimatedCosts(for: events)
        let groupedEvents = groupEventsByType(events)

        var summary = "Upcoming events for the rest of the month:\n"
        summary += "• Total events: \(events.count)\n"
        summary += "• Estimated total cost: $\(String(format: "%.2f", totalCost))\n\n"

        summary += "Breakdown by type:\n"
        for (eventType, typeEvents) in groupedEvents.sorted(by: { $0.key.rawValue < $1.key.rawValue }) {
            let typeCost = typeEvents.compactMap { $0.estimatedCost }.reduce(0, +)
            summary += "• \(eventType.rawValue.capitalized): \(typeEvents.count) events, ~$\(String(format: "%.2f", typeCost))\n"
        }

        // Highlight expensive events
        let expensiveEvents = events.filter { ($0.estimatedCost ?? 0) > 50 }
        if !expensiveEvents.isEmpty {
            summary += "\nLarge expenses coming up:\n"
            for event in expensiveEvents.prefix(3) {
                let dateFormatter = DateFormatter()
                dateFormatter.dateStyle = .medium
                summary += "• \(event.title): $\(String(format: "%.2f", event.estimatedCost ?? 0)) on \(dateFormatter.string(from: event.startDate))\n"
            }
        }

        return summary
    }

    // MARK: - Helper Methods

    /// Checks if calendar permission is available
    func hasCalendarPermission() -> Bool {
        let authStatus = EKEventStore.authorizationStatus(for: .event)
        return hasValidCalendarPermission(authStatus)
    }

    /// Helper function to check valid calendar permissions across iOS versions
    private func hasValidCalendarPermission(_ status: EKAuthorizationStatus) -> Bool {
        if #available(iOS 17.0, *) {
            return status == .fullAccess || status == .writeOnly
        } else {
            return status == .authorized
        }
    }
}

// MARK: - Preview Helper

#if DEBUG
extension CalendarService {
    /// Creates mock calendar events for testing
    static func createMockEvents() -> [CalendarEventData] {
        let calendar = Calendar.current
        let today = Date()

        return [
            CalendarEventData(
                title: "Dinner at Italian Restaurant",
                location: "Mario's Italian Bistro",
                startDate: calendar.date(byAdding: .day, value: 2, to: today) ?? today,
                endDate: calendar.date(byAdding: .hour, value: 2, to: calendar.date(byAdding: .day, value: 2, to: today) ?? today) ?? today,
                estimatedCost: 65.0,
                eventType: .dining
            ),
            CalendarEventData(
                title: "Movie Night",
                location: "AMC Theater",
                startDate: calendar.date(byAdding: .day, value: 5, to: today) ?? today,
                endDate: calendar.date(byAdding: .hour, value: 3, to: calendar.date(byAdding: .day, value: 5, to: today) ?? today) ?? today,
                estimatedCost: 15.0,
                eventType: .entertainment
            ),
            CalendarEventData(
                title: "Coffee with Sarah",
                location: "Starbucks Downtown",
                startDate: calendar.date(byAdding: .day, value: 1, to: today) ?? today,
                endDate: calendar.date(byAdding: .hour, value: 1, to: calendar.date(byAdding: .day, value: 1, to: today) ?? today) ?? today,
                estimatedCost: 8.0,
                eventType: .social
            )
        ]
    }
}
#endif