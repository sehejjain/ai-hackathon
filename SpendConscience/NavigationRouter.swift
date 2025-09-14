//
//  NavigationRouter.swift
//  SpendConscience
//
//  Created by AI Assistant
//

import SwiftUI

// MARK: - Navigation Action Type
typealias NavigationAction = (Destination) -> Void

// MARK: - Navigation Path Environment Key
struct NavigationPathKey: EnvironmentKey {
    static let defaultValue: Binding<NavigationPath> = .constant(NavigationPath())
}

// MARK: - Navigation Environment Key
struct NavigationKey: EnvironmentKey {
    static let defaultValue: NavigationAction = { _ in }
}

// MARK: - Environment Values Extension
extension EnvironmentValues {
    var navigationPath: Binding<NavigationPath> {
        get { self[NavigationPathKey.self] }
        set { self[NavigationPathKey.self] = newValue }
    }
    
    var navigate: NavigationAction {
        get { self[NavigationKey.self] }
        set { self[NavigationKey.self] = newValue }
    }
}

// MARK: - Navigation Router Convenience Functions

/// Navigate to transaction history
func navigateToTransactionHistory(_ navigate: NavigationAction) {
    navigate(.transactionHistory)
}

/// Navigate to expenses view
func navigateToExpenses(_ navigate: NavigationAction) {
    navigate(.expenses)
}

/// Navigate to profile view
func navigateToProfile(_ navigate: NavigationAction) {
    navigate(.profile)
}

/// Navigate to AI assistant
func navigateToAIAssistant(_ navigate: NavigationAction) {
    navigate(.aiAssistant)
}
