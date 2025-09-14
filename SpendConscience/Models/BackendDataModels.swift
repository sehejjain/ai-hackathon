//
//  BackendDataModels.swift
//  SpendConscience
//
//  Created by AI Assistant on 9/14/2025.
//

import Foundation

// MARK: - Backend Transaction Model
struct BackendTransaction: Codable, Identifiable {
    let id: String
    let amount: Double
    let description: String
    let category: String
    let date: Date
    let accountId: String
    let merchantName: String?
    let isoCurrencyCode: String?
    let accountName: String?
    
    enum CodingKeys: String, CodingKey {
        case id
        case amount
        case description
        case category
        case date
        case accountId = "account_id"
        case merchantName = "merchant_name"
        case isoCurrencyCode = "iso_currency_code"
        case accountName = "account_name"
    }
    
    // Convert to local Transaction model
    func toLocalTransaction() -> Transaction? {
        return try? Transaction(from: self)
    }
}

// MARK: - Backend Budget Model
struct BackendBudget: Codable, Identifiable {
    let id: String
    let category: String
    let monthlyLimit: Double
    let currentSpent: Double
    let utilizationPercentage: Double
    let period: String
    let startDate: Date
    let endDate: Date
    
    enum CodingKeys: String, CodingKey {
        case id
        case category
        case monthlyLimit = "monthly_limit"
        case currentSpent = "current_spent"
        case utilizationPercentage = "utilization_percentage"
        case period
        case startDate = "start_date"
        case endDate = "end_date"
    }
    
    // Convert to local Budget model
    func toLocalBudget() -> Budget? {
        do {
            return try Budget(
                id: UUID(uuidString: id) ?? UUID(),
                category: TransactionCategory(rawValue: category) ?? .other,
                monthlyLimit: Decimal(monthlyLimit),
                currentSpent: Decimal(currentSpent)
            )
        } catch {
            print("Failed to create Budget from BackendBudget: \(error)")
            return nil
        }
    }
}

// MARK: - Restaurant Alternative Model
struct RestaurantAlternative: Codable, Identifiable {
    let id: String
    let name: String
    let address: String
    let priceLevel: Int
    let rating: Double?
    let estimatedCost: Double?
    let distance: Double
    let placeId: String?
    let phoneNumber: String?
    let website: String?
    let openNow: Bool?
    
    enum CodingKeys: String, CodingKey {
        case id
        case name
        case address
        case priceLevel = "price_level"
        case rating
        case estimatedCost = "estimated_cost"
        case distance
        case placeId = "place_id"
        case phoneNumber = "phone_number"
        case website
        case openNow = "open_now"
    }
    
    var priceDescription: String {
        switch priceLevel {
        case 1:
            return "$"
        case 2:
            return "$$"
        case 3:
            return "$$$"
        case 4:
            return "$$$$"
        default:
            return "Price not available"
        }
    }
    
    var distanceDescription: String {
        if distance < 1000 {
            return String(format: "%.0f m", distance)
        } else {
            return String(format: "%.1f km", distance / 1000)
        }
    }
}

// MARK: - Backend Account Summary Model
struct BackendAccountSummary: Codable, Identifiable {
    let id: String
    let accountId: String
    let accountName: String
    let accountType: String
    let balance: Double
    let availableBalance: Double?
    let currencyCode: String
    let lastUpdated: Date
    
    enum CodingKeys: String, CodingKey {
        case id
        case accountId = "account_id"
        case accountName = "account_name"
        case accountType = "account_type"
        case balance
        case availableBalance = "available_balance"
        case currencyCode = "currency_code"
        case lastUpdated = "last_updated"
    }
}

// MARK: - Backend Response Wrapper
struct BackendDataResponse: Codable {
    let transactions: [BackendTransaction]?
    let budgets: [BackendBudget]?
    let accountSummaries: [BackendAccountSummary]?
    let restaurantAlternatives: [RestaurantAlternative]?
    let message: String?
    let success: Bool
    
    enum CodingKeys: String, CodingKey {
        case transactions
        case budgets
        case accountSummaries = "account_summaries"
        case restaurantAlternatives = "restaurant_alternatives"
        case message
        case success
    }
}

// MARK: - Data Conversion Utilities
extension Array where Element == BackendTransaction {
    func toLocalTransactions() -> [Transaction] {
        return self.compactMap { $0.toLocalTransaction() }
    }
}

extension Array where Element == BackendBudget {
    func toLocalBudgets() -> [Budget] {
        return self.compactMap { $0.toLocalBudget() }
    }
}

// MARK: - Validation Extensions
extension BackendTransaction {
    var isValid: Bool {
        return !id.isEmpty && 
               !description.isEmpty && 
               !category.isEmpty && 
               !accountId.isEmpty
    }
}

extension BackendBudget {
    var isValid: Bool {
        return !id.isEmpty && 
               !category.isEmpty && 
               monthlyLimit > 0 && 
               currentSpent >= 0 && 
               utilizationPercentage >= 0
    }
}

extension RestaurantAlternative {
    var isValid: Bool {
        return !id.isEmpty && 
               !name.isEmpty && 
               !address.isEmpty && 
               priceLevel >= 0 && 
               priceLevel <= 4 && 
               distance >= 0
    }
}

// MARK: - Error Handling for Data Conversion
enum BackendDataError: LocalizedError {
    case invalidTransactionData(String)
    case invalidBudgetData(String)
    case invalidRestaurantData(String)
    case conversionFailed(String)
    
    var errorDescription: String? {
        switch self {
        case .invalidTransactionData(let details):
            return "Invalid transaction data: \(details)"
        case .invalidBudgetData(let details):
            return "Invalid budget data: \(details)"
        case .invalidRestaurantData(let details):
            return "Invalid restaurant data: \(details)"
        case .conversionFailed(let details):
            return "Data conversion failed: \(details)"
        }
    }
}
