//
//  NotificationTemplate.swift
//  SpendConscience
//
//  Created by AI Assistant
//

import Foundation
import UserNotifications

// MARK: - Core Template Structure

/// A comprehensive notification template system for personalized budget notifications
struct NotificationTemplate {
    let id: String
    let type: TemplateType
    let content: TemplateContent
    let timing: NotificationTiming
    
    init(id: String = UUID().uuidString, type: TemplateType, content: TemplateContent, timing: NotificationTiming) {
        self.id = id
        self.type = type
        self.content = content
        self.timing = timing
    }
}

// MARK: - Template Types

/// Defines the different types of notification templates available
enum TemplateType {
    case budgetWarning(threshold: Double)
    case budgetOverrun
    case spendingRecommendation(type: RecommendationType)
    
    var identifier: String {
        switch self {
        case .budgetWarning(let threshold):
            return "budget_warning_\(Int(threshold * 100))"
        case .budgetOverrun:
            return "budget_overrun"
        case .spendingRecommendation(let type):
            return "spending_recommendation_\(type.rawValue)"
        }
    }
}

// MARK: - Template Content System

/// Contains the template strings and placeholders for dynamic content generation
struct TemplateContent {
    let titleTemplate: String
    let bodyTemplate: String
    let placeholders: [String: Any]
    
    init(titleTemplate: String, bodyTemplate: String, placeholders: [String: Any] = [:]) {
        self.titleTemplate = titleTemplate
        self.bodyTemplate = bodyTemplate
        self.placeholders = placeholders
    }
}

// MARK: - Timing Configuration

/// Defines when and how notifications should be triggered
struct NotificationTiming {
    let triggerCondition: TriggerCondition
    let timeInterval: TimeInterval?
    let dateComponents: DateComponents?
    let repeatInterval: RepeatInterval?
    
    init(triggerCondition: TriggerCondition, timeInterval: TimeInterval? = nil, dateComponents: DateComponents? = nil, repeatInterval: RepeatInterval? = nil) {
        self.triggerCondition = triggerCondition
        self.timeInterval = timeInterval
        self.dateComponents = dateComponents
        self.repeatInterval = repeatInterval
    }
}

/// Defines when a notification should be triggered
enum TriggerCondition {
    case immediate
    case delayed
    case scheduled
}

/// Defines how often a notification should repeat
enum RepeatInterval {
    case daily
    case weekly
    case monthly
    case never
    
    var calendarComponent: Calendar.Component? {
        switch self {
        case .daily: return .day
        case .weekly: return .weekOfYear
        case .monthly: return .month
        case .never: return nil
        }
    }
}

// MARK: - Recommendation Types

/// Types of spending recommendations that can be provided
enum RecommendationType: String, CaseIterable {
    case reduceSpending = "reduce_spending"
    case categoryReallocation = "category_reallocation"
    case savingsOpportunity = "savings_opportunity"
    
    var displayName: String {
        switch self {
        case .reduceSpending:
            return "Reduce Spending"
        case .categoryReallocation:
            return "Category Reallocation"
        case .savingsOpportunity:
            return "Savings Opportunity"
        }
    }
}

// MARK: - Template Factory Methods

extension NotificationTemplate {
    
    /// Creates a budget warning template for when spending reaches a threshold
    static func budgetWarningTemplate(for budget: Budget) -> NotificationTemplate {
        let threshold = budget.alertThreshold
        let utilizationPercentage = Int(budget.utilizationPercentage * 100)
        let remainingAmount = budget.remainingAmount
        let categoryIcon = budget.category.systemIcon
        
        let content = TemplateContent(
            titleTemplate: "{categoryIcon} Budget Alert: {categoryName}",
            bodyTemplate: "You've used {utilizationPercentage}% of your {categoryName} budget. ${remainingAmount} remaining. Consider reducing spending to stay on track! 💡",
            placeholders: [
                "categoryIcon": categoryIcon,
                "categoryName": budget.category.displayName,
                "utilizationPercentage": utilizationPercentage,
                "remainingAmount": String(format: "%.2f", NSDecimalNumber(decimal: remainingAmount).doubleValue)
            ]
        )
        
        let timing = NotificationTiming(
            triggerCondition: .immediate,
            timeInterval: 0
        )
        
        return NotificationTemplate(
            type: .budgetWarning(threshold: threshold),
            content: content,
            timing: timing
        )
    }
    
    /// Creates a budget overrun template for when spending exceeds the budget
    static func budgetOverrunTemplate(for budget: Budget) -> NotificationTemplate {
        let overrunAmount = budget.currentSpent - budget.monthlyLimit
        let _ = budget.category.systemIcon
        
        let content = TemplateContent(
            titleTemplate: "🚨 Budget Exceeded: {categoryName}",
            bodyTemplate: "You've exceeded your {categoryName} budget by ${overrunAmount}! Time to review your spending and adjust your budget or reduce expenses. 📊",
            placeholders: [
                "categoryName": budget.category.displayName,
                "overrunAmount": String(format: "%.2f", NSDecimalNumber(decimal: overrunAmount).doubleValue)
            ]
        )
        
        let timing = NotificationTiming(
            triggerCondition: .immediate,
            timeInterval: 0
        )
        
        return NotificationTemplate(
            type: .budgetOverrun,
            content: content,
            timing: timing
        )
    }
    
    /// Creates a spending recommendation template
    static func spendingRecommendationTemplate(for budget: Budget, type: RecommendationType) -> NotificationTemplate {
        let categoryIcon = budget.category.systemIcon
        let utilizationPercentage = Int(budget.utilizationPercentage * 100)
        
        let (titleTemplate, bodyTemplate) = recommendationContent(for: type, budget: budget)
        
        let remainingAmountDecimal = budget.remainingAmount
        let remainingAmount = String(format: "%.2f", NSDecimalNumber(decimal: remainingAmountDecimal).doubleValue)
        
        let content = TemplateContent(
            titleTemplate: titleTemplate,
            bodyTemplate: bodyTemplate,
            placeholders: [
                "categoryIcon": categoryIcon,
                "categoryName": budget.category.displayName,
                "utilizationPercentage": utilizationPercentage,
                "spentAmount": String(format: "%.2f", NSDecimalNumber(decimal: budget.currentSpent).doubleValue),
                "limitAmount": String(format: "%.2f", NSDecimalNumber(decimal: budget.monthlyLimit).doubleValue),
                "remainingAmount": remainingAmount
            ]
        )
        
        let timing = NotificationTiming(
            triggerCondition: .delayed,
            timeInterval: 3600 // 1 hour delay for recommendations
        )
        
        return NotificationTemplate(
            type: .spendingRecommendation(type: type),
            content: content,
            timing: timing
        )
    }
    
    /// Generates recommendation content based on type
    private static func recommendationContent(for type: RecommendationType, budget: Budget) -> (String, String) {
        let _ = budget.category.systemIcon
        
        switch type {
        case .reduceSpending:
            return (
                "{categoryIcon} Spending Tip: {categoryName}",
                "You've spent ${spentAmount} of your ${limitAmount} {categoryName} budget ({utilizationPercentage}%). Consider reducing spending in this category to maintain financial balance. 💰"
            )
        case .categoryReallocation:
            return (
                "💡 Budget Optimization: {categoryName}",
                "Your {categoryName} spending pattern suggests you might benefit from reallocating budget between categories. Review your spending habits for better balance! 📈"
            )
        case .savingsOpportunity:
            return (
                "🎯 Savings Opportunity: {categoryName}",
                "Great job managing your {categoryName} budget! You're at {utilizationPercentage}% usage. Consider saving the remaining ${remainingAmount} for future goals! 🏆"
            )
        }
    }
}

// MARK: - Content Generation

extension NotificationTemplate {
    
    /// Processes template strings with placeholders to generate final notification content
    func generateContent() -> (title: String, body: String) {
        let title = processTemplate(content.titleTemplate, with: content.placeholders)
        let body = processTemplate(content.bodyTemplate, with: content.placeholders)
        return (title: title, body: body)
    }
    
    /// Generates a unique identifier for the notification
    func generateIdentifier() -> String {
        let raw = "\(type.identifier)_\(id)"
        // sanitize: replace non-alphanumerics with `_`, collapse repeats, trim
        let sanitized = raw.replacingOccurrences(of: "[^a-zA-Z0-9]", with: "_", options: .regularExpression)
            .replacingOccurrences(of: "_+", with: "_", options: .regularExpression)
            .trimmingCharacters(in: CharacterSet(charactersIn: "_"))
        return sanitized.isEmpty ? "budget_\(abs(raw.hashValue))" : sanitized
    }
    
    /// Determines if the template conditions are met for the given budget
    func shouldTrigger(for budget: Budget) -> Bool {
        switch type {
        case .budgetWarning(let threshold):
            return budget.utilizationPercentage >= threshold && !budget.isOverBudget
        case .budgetOverrun:
            return budget.isOverBudget
        case .spendingRecommendation:
            return budget.utilizationPercentage > 0.5 // Trigger recommendations after 50% usage
        }
    }
    
    /// Processes a template string by replacing placeholders with actual values
    private func processTemplate(_ template: String, with placeholders: [String: Any]) -> String {
        var result = template
        
        for (key, value) in placeholders {
            let placeholder = "{\(key)}"
            let replacement = String(describing: value)
            result = result.replacingOccurrences(of: placeholder, with: replacement)
        }
        
        return result
    }
}

// MARK: - NotificationService Integration

extension NotificationTemplate {
    
    /// Schedules the notification using the existing NotificationService
    func scheduleNotification(using service: NotificationService) async throws {
        try await scheduleNotification(using: service, overrideIdentifier: nil)
    }
    
    /// Schedules the notification using the existing NotificationService with optional override identifier
    func scheduleNotification(using service: NotificationService, overrideIdentifier: String?) async throws {
        switch validateTemplate() {
        case .invalid(let errors):
            throw NotificationError.schedulingFailed("Invalid template: \(errors.joined(separator: ", "))")
        case .valid: break
        }
        
        let (title, body) = generateContent()
        let category = mapToCategoryIdentifier()
        let id = overrideIdentifier ?? generateIdentifier()

        switch timing.triggerCondition {
        case .immediate:
            try await service.scheduleNotification(
                identifier: id,
                title: title,
                body: body,
                timeInterval: 1,
                categoryIdentifier: category
            )
        case .delayed:
            let interval = max(1, timing.timeInterval ?? 60)
            try await service.scheduleNotification(
                identifier: id,
                title: title,
                body: body,
                timeInterval: interval,
                categoryIdentifier: category
            )
        case .scheduled:
            guard let dateComponents = timing.dateComponents else { throw NotificationError.schedulingFailed("Missing dateComponents") }
            try await service.scheduleRepeatingNotification(
                identifier: id,
                title: title,
                body: body,
                dateComponents: dateComponents,
                categoryIdentifier: category
            )
        }
    }
    
    /// Maps template types to NotificationService CategoryIdentifier
    private func mapToCategoryIdentifier() -> NotificationService.CategoryIdentifier {
        switch type {
        case .budgetWarning, .budgetOverrun:
            return .budgetAlert
        case .spendingRecommendation:
            return .budgetAlert // Using budgetAlert for recommendations as well
        }
    }
    
    /// Creates appropriate notification trigger based on timing configuration
    private func createNotificationTrigger() -> UNNotificationTrigger? {
        switch timing.triggerCondition {
        case .immediate:
            if let interval = timing.timeInterval, interval > 0 {
                return UNTimeIntervalNotificationTrigger(timeInterval: interval, repeats: false)
            }
            return nil // Immediate delivery
            
        case .delayed:
            let interval = timing.timeInterval ?? 60 // Default 1 minute delay
            return UNTimeIntervalNotificationTrigger(timeInterval: interval, repeats: false)
            
        case .scheduled:
            guard let dateComponents = timing.dateComponents else { return nil }
            let repeats = timing.repeatInterval.map { $0 != .never } ?? false
            return UNCalendarNotificationTrigger(dateMatching: dateComponents, repeats: repeats)
        }
    }
}

// MARK: - Template Validation

extension NotificationTemplate {
    
    /// Validates that the template has all required placeholders
    func validateTemplate() -> ValidationResult {
        var errors: [String] = []
        
        // Check for required placeholders in templates
        let requiredPlaceholders = extractPlaceholders(from: content.titleTemplate) + 
                                 extractPlaceholders(from: content.bodyTemplate)
        
        for placeholder in requiredPlaceholders {
            if content.placeholders[placeholder] == nil {
                errors.append("Missing placeholder value for: \(placeholder)")
            }
        }
        
        // Validate timing configuration
        if timing.triggerCondition == .scheduled && timing.dateComponents == nil {
            errors.append("Scheduled notifications require dateComponents")
        }
        
        if timing.triggerCondition == .delayed && timing.timeInterval == nil {
            errors.append("Delayed notifications require timeInterval")
        }
        
        return errors.isEmpty ? .valid : .invalid(errors: errors)
    }
    
    /// Extracts placeholder names from a template string
    private func extractPlaceholders(from template: String) -> [String] {
        let pattern = "\\{([^}]+)\\}"
        let regex = try! NSRegularExpression(pattern: pattern)
        let matches = regex.matches(in: template, range: NSRange(template.startIndex..., in: template))
        
        return matches.compactMap { match in
            guard let range = Range(match.range(at: 1), in: template) else { return nil }
            return String(template[range])
        }
    }
}

/// Result of template validation
enum ValidationResult {
    case valid
    case invalid(errors: [String])
    
    var isValid: Bool {
        switch self {
        case .valid: return true
        case .invalid: return false
        }
    }
}

// MARK: - Default Templates

extension NotificationTemplate {
    
    /// Provides a collection of default templates for common scenarios
    static var defaultTemplates: [NotificationTemplate] {
        return [
            // Default budget warning template
            NotificationTemplate(
                type: .budgetWarning(threshold: 0.8),
                content: TemplateContent(
                    titleTemplate: "💰 Budget Alert",
                    bodyTemplate: "You're approaching your spending limit. Consider reviewing your expenses to stay on track!"
                ),
                timing: NotificationTiming(triggerCondition: .immediate)
            ),
            
            // Default budget overrun template
            NotificationTemplate(
                type: .budgetOverrun,
                content: TemplateContent(
                    titleTemplate: "🚨 Budget Exceeded",
                    bodyTemplate: "You've exceeded your budget limit. Time to review and adjust your spending!"
                ),
                timing: NotificationTiming(triggerCondition: .immediate)
            ),
            
            // Default spending recommendation template
            NotificationTemplate(
                type: .spendingRecommendation(type: .reduceSpending),
                content: TemplateContent(
                    titleTemplate: "💡 Spending Tip",
                    bodyTemplate: "Based on your spending patterns, here's a tip to help you save money and stay within budget."
                ),
                timing: NotificationTiming(
                    triggerCondition: .delayed,
                    timeInterval: 3600
                )
            )
        ]
    }
}
