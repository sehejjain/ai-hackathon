//
//  NavigationDestination.swift
//  SpendConscience
//
//  Created by AI Assistant
//

import Foundation

// MARK: - Navigation Destination Enum

enum Destination: Hashable {
    case budgetDetail(Budget)
    case transactionDetail(Transaction)
    case transactionEdit(Transaction)
    case transactionHistory
    case expenses
    case profile
    case aiAssistant
}
