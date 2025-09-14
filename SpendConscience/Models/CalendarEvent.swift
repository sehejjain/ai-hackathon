//
//  CalendarEvent.swift
//  SpendConscience
//
//  Calendar event models for AI integration
//

import Foundation
import EventKit

/// Calendar event data structure for AI analysis
struct CalendarEventData: Codable {
    let title: String
    let location: String?
    let startDate: Date
    let endDate: Date
    let estimatedCost: Double?
    let eventType: EventType

    enum EventType: String, Codable {
        case dining = "dining"
        case entertainment = "entertainment"
        case travel = "travel"
        case social = "social"
        case shopping = "shopping"
        case other = "other"
    }
}

/// Extension to create CalendarEventData from EKEvent
extension CalendarEventData {
    init(from event: EKEvent) {
        self.title = event.title ?? "Untitled Event"
        self.location = event.location
        self.startDate = event.startDate
        self.endDate = event.endDate
        self.eventType = EventType.detectFrom(title: self.title, location: self.location)
        self.estimatedCost = EstimatedCostCalculator.calculate(for: self.eventType, title: self.title, location: self.location)
    }
}

/// Helper to detect event type from title and location
extension CalendarEventData.EventType {
    static func detectFrom(title: String, location: String?) -> CalendarEventData.EventType {
        let titleLower = title.lowercased()
        let locationLower = location?.lowercased() ?? ""

        // Dining keywords
        if titleLower.contains("dinner") || titleLower.contains("lunch") || titleLower.contains("breakfast") ||
           titleLower.contains("restaurant") || titleLower.contains("cafe") || titleLower.contains("meal") ||
           locationLower.contains("restaurant") || locationLower.contains("cafe") || locationLower.contains("bar") {
            return .dining
        }

        // Entertainment keywords
        if titleLower.contains("movie") || titleLower.contains("concert") || titleLower.contains("show") ||
           titleLower.contains("theater") || titleLower.contains("game") || titleLower.contains("event") ||
           locationLower.contains("theater") || locationLower.contains("cinema") || locationLower.contains("stadium") {
            return .entertainment
        }

        // Travel keywords
        if titleLower.contains("flight") || titleLower.contains("trip") || titleLower.contains("vacation") ||
           titleLower.contains("travel") || titleLower.contains("hotel") ||
           locationLower.contains("airport") || locationLower.contains("hotel") {
            return .travel
        }

        // Shopping keywords
        if titleLower.contains("shopping") || titleLower.contains("buy") || titleLower.contains("purchase") ||
           locationLower.contains("mall") || locationLower.contains("store") {
            return .shopping
        }

        // Social keywords
        if titleLower.contains("party") || titleLower.contains("meetup") || titleLower.contains("hangout") ||
           titleLower.contains("drinks") || titleLower.contains("coffee") {
            return .social
        }

        return .other
    }
}

/// Cost estimation calculator for different event types
struct EstimatedCostCalculator {
    static func calculate(for eventType: CalendarEventData.EventType, title: String, location: String?) -> Double? {
        let titleLower = title.lowercased()
        let locationLower = location?.lowercased() ?? ""

        switch eventType {
        case .dining:
            // Try to detect restaurant type from location/title
            if locationLower.contains("fine") || locationLower.contains("upscale") ||
               titleLower.contains("fine dining") {
                return 80.0
            } else if locationLower.contains("fast") || locationLower.contains("quick") ||
                     titleLower.contains("fast food") || titleLower.contains("quick") {
                return 12.0
            } else if titleLower.contains("coffee") || titleLower.contains("cafe") {
                return 8.0
            } else {
                return 35.0 // Default restaurant meal
            }

        case .entertainment:
            if titleLower.contains("movie") || titleLower.contains("cinema") {
                return 15.0
            } else if titleLower.contains("concert") || titleLower.contains("show") {
                return 60.0
            } else if titleLower.contains("game") || titleLower.contains("sport") {
                return 45.0
            } else {
                return 30.0
            }

        case .travel:
            if titleLower.contains("flight") {
                return 300.0
            } else if titleLower.contains("hotel") {
                return 120.0
            } else if titleLower.contains("gas") || titleLower.contains("fuel") {
                return 40.0
            } else {
                return 80.0
            }

        case .shopping:
            if titleLower.contains("grocery") || titleLower.contains("groceries") {
                return 75.0
            } else if titleLower.contains("clothes") || titleLower.contains("clothing") {
                return 100.0
            } else {
                return 50.0
            }

        case .social:
            if titleLower.contains("drinks") {
                return 25.0
            } else if titleLower.contains("coffee") {
                return 6.0
            } else {
                return 20.0
            }

        case .other:
            return nil // No estimate for generic events
        }
    }
}