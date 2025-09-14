//
//  ErrorRecoveryManager.swift
//  SpendConscience
//
//  Comprehensive error handling and recovery system
//

import Foundation
import SwiftUI
import OSLog

/// Centralized error recovery and user feedback system
class ErrorRecoveryManager: ObservableObject {
    
    // MARK: - Published Properties
    
    @Published var currentError: AppError?
    @Published var isRecovering: Bool = false
    @Published var recoveryAttempts: Int = 0
    @Published var lastRecoveryTime: Date?
    
    // MARK: - Private Properties
    
    private let logger = Logger(subsystem: "SpendConscience", category: "ErrorRecovery")
    private let maxRecoveryAttempts = 3
    private let recoveryDelayInterval: TimeInterval = 2.0
    
    // MARK: - Error Types
    
    enum AppError: Error, LocalizedError, Identifiable, Equatable {
        case networkConnection
        case serverUnavailable
        case dataCorruption
        case authenticationFailed
        case insufficientStorage
        case backgroundSync(String)
        case plaidConnection(String)
        case locationServices(String)
        case dataConversion(String)
        case unknown(String)
        
        var id: String {
            switch self {
            case .networkConnection: return "network_connection"
            case .serverUnavailable: return "server_unavailable"
            case .dataCorruption: return "data_corruption"
            case .authenticationFailed: return "authentication_failed"
            case .insufficientStorage: return "insufficient_storage"
            case .backgroundSync: return "background_sync"
            case .plaidConnection: return "plaid_connection"
            case .locationServices: return "location_services"
            case .dataConversion: return "data_conversion"
            case .unknown: return "unknown"
            }
        }
        
        var errorDescription: String? {
            switch self {
            case .networkConnection:
                return "No internet connection. Please check your network settings and try again."
            case .serverUnavailable:
                return "The server is temporarily unavailable. Please try again in a few moments."
            case .dataCorruption:
                return "There was an issue with your data. We're attempting to recover it automatically."
            case .authenticationFailed:
                return "Authentication failed. Please check your credentials and try again."
            case .insufficientStorage:
                return "Not enough storage space available. Please free up some space and try again."
            case .backgroundSync(let details):
                return "Background sync failed: \(details)"
            case .plaidConnection(let details):
                return "Bank connection issue: \(details)"
            case .locationServices(let details):
                return "Location services error: \(details)"
            case .dataConversion(let details):
                return "Data processing error: \(details)"
            case .unknown(let details):
                return "An unexpected error occurred: \(details)"
            }
        }
        
        var severity: ErrorSeverity {
            switch self {
            case .networkConnection, .serverUnavailable:
                return .medium
            case .dataCorruption, .insufficientStorage:
                return .high
            case .authenticationFailed:
                return .high
            case .backgroundSync, .dataConversion:
                return .low
            case .plaidConnection, .locationServices:
                return .medium
            case .unknown:
                return .medium
            }
        }
        
        var canRecover: Bool {
            switch self {
            case .networkConnection, .serverUnavailable, .backgroundSync, .plaidConnection:
                return true
            case .dataCorruption, .authenticationFailed, .insufficientStorage, .locationServices, .dataConversion, .unknown:
                return false
            }
        }
        
        var userActionRequired: Bool {
            switch self {
            case .networkConnection, .authenticationFailed, .insufficientStorage:
                return true
            case .serverUnavailable, .dataCorruption, .backgroundSync, .plaidConnection, .locationServices, .dataConversion, .unknown:
                return false
            }
        }
    }
    
    enum ErrorSeverity {
        case low, medium, high
        
        var color: Color {
            switch self {
            case .low: return .blue
            case .medium: return .orange
            case .high: return .red
            }
        }
        
        var icon: String {
            switch self {
            case .low: return "info.circle"
            case .medium: return "exclamationmark.triangle"
            case .high: return "xmark.circle"
            }
        }
    }
    
    // MARK: - Recovery Actions
    
    enum RecoveryAction {
        case retry
        case refreshData
        case clearCache
        case reconnectPlaid
        case enableLocation
        case contactSupport
        case dismiss
        
        var title: String {
            switch self {
            case .retry: return "Try Again"
            case .refreshData: return "Refresh Data"
            case .clearCache: return "Clear Cache"
            case .reconnectPlaid: return "Reconnect Bank"
            case .enableLocation: return "Enable Location"
            case .contactSupport: return "Contact Support"
            case .dismiss: return "Dismiss"
            }
        }
        
        var isDestructive: Bool {
            switch self {
            case .clearCache:
                return true
            default:
                return false
            }
        }
    }
    
    // MARK: - Public Methods
    
    /// Handles an error with automatic recovery attempts
    func handleError(_ error: Error, context: String = "") {
        logger.error("Handling error in context '\(context)': \(error.localizedDescription)")
        
        let appError = convertToAppError(error, context: context)
        
        Task { @MainActor in
            currentError = appError
            
            // Attempt automatic recovery for recoverable errors
            if appError.canRecover && !appError.userActionRequired {
                await attemptRecovery(for: appError)
            }
        }
    }
    
    /// Manually attempt recovery for an error
    func attemptRecovery(for error: AppError) async {
        guard error.canRecover && recoveryAttempts < maxRecoveryAttempts else {
            logger.warning("Cannot recover from error or max attempts reached: \(error.localizedDescription ?? "Unknown error")")
            return
        }
        
        await MainActor.run {
            isRecovering = true
            recoveryAttempts += 1
            lastRecoveryTime = Date()
        }
        
        logger.info("Attempting recovery for error: \(error.id), attempt \(self.recoveryAttempts)")
        
        // Wait before retry
        try? await Task.sleep(nanoseconds: UInt64(recoveryDelayInterval * Double(recoveryAttempts) * 1_000_000_000))
        
        switch error {
        case .networkConnection, .serverUnavailable:
            await attemptNetworkRecovery()
        case .backgroundSync:
            await attemptSyncRecovery()
        case .plaidConnection:
            await attemptPlaidRecovery()
        default:
            logger.warning("No recovery strategy for error: \(error.id)")
        }
        
        await MainActor.run {
            isRecovering = false
        }
    }
    
    /// Clears the current error
    func clearError() {
        Task { @MainActor in
            currentError = nil
            recoveryAttempts = 0
            lastRecoveryTime = nil
        }
    }
    
    /// Gets available recovery actions for the current error
    func getRecoveryActions() -> [RecoveryAction] {
        guard let error = currentError else { return [.dismiss] }
        
        switch error {
        case .networkConnection:
            return [.retry, .dismiss]
        case .serverUnavailable:
            return [.retry, .refreshData, .dismiss]
        case .dataCorruption:
            return [.refreshData, .clearCache, .contactSupport, .dismiss]
        case .authenticationFailed:
            return [.retry, .contactSupport, .dismiss]
        case .insufficientStorage:
            return [.clearCache, .dismiss]
        case .backgroundSync:
            return [.retry, .refreshData, .dismiss]
        case .plaidConnection:
            return [.reconnectPlaid, .retry, .dismiss]
        case .locationServices:
            return [.enableLocation, .dismiss]
        case .dataConversion:
            return [.refreshData, .retry, .dismiss]
        case .unknown:
            return [.retry, .contactSupport, .dismiss]
        }
    }
    
    /// Executes a recovery action
    func executeRecoveryAction(_ action: RecoveryAction) {
        logger.info("Executing recovery action: \(action.title)")
        
        switch action {
        case .retry:
            if let error = currentError {
                Task {
                    await attemptRecovery(for: error)
                }
            }
        case .refreshData:
            NotificationCenter.default.post(name: .refreshAllData, object: nil)
            clearError()
        case .clearCache:
            NotificationCenter.default.post(name: .clearAppCache, object: nil)
            clearError()
        case .reconnectPlaid:
            NotificationCenter.default.post(name: .reconnectPlaid, object: nil)
            clearError()
        case .enableLocation:
            NotificationCenter.default.post(name: .requestLocationPermission, object: nil)
            clearError()
        case .contactSupport:
            NotificationCenter.default.post(name: .contactSupport, object: nil)
            clearError()
        case .dismiss:
            clearError()
        }
    }
    
    // MARK: - Private Methods
    
    private func convertToAppError(_ error: Error, context: String) -> AppError {
        if let appError = error as? AppError {
            return appError
        }
        
        // Convert known error types
        if let networkError = error as? NetworkError {
            switch networkError {
            case .noInternetConnection:
                return .networkConnection
            case .serverUnavailable:
                return .serverUnavailable
            default:
                return .unknown(networkError.localizedDescription)
            }
        }
        
        if let apiError = error as? SpendConscienceAPIError {
            switch apiError {
            case .networkError:
                return .networkConnection
            case .serverError:
                return .serverUnavailable
            case .locationDenied, .locationUnavailable:
                return .locationServices(apiError.localizedDescription)
            default:
                return .unknown(apiError.localizedDescription)
            }
        }
        
        if let dataError = error as? DataManager.DataError {
            switch dataError {
            case .backendConnectionFailed, .backendBudgetConnectionFailed:
                return .serverUnavailable
            case .backendDataConversionFailed, .backendBudgetDataConversionFailed:
                return .dataConversion(dataError.localizedDescription)
            case .transactionLoadFailed, .budgetLoadFailed:
                return .dataCorruption
            default:
                return .unknown(dataError.localizedDescription)
            }
        }
        
        // Default to unknown error
        return .unknown(error.localizedDescription)
    }
    
    private func attemptNetworkRecovery() async {
        // Try a simple network test
        guard let url = URL(string: "https://www.apple.com") else { return }
        
        do {
            let (_, response) = try await URLSession.shared.data(from: url)
            if let httpResponse = response as? HTTPURLResponse, httpResponse.statusCode == 200 {
                logger.info("Network recovery successful")
                await MainActor.run {
                    clearError()
                }
            }
        } catch {
            logger.warning("Network recovery failed: \(error.localizedDescription)")
        }
    }
    
    private func attemptSyncRecovery() async {
        // Trigger a data refresh
        NotificationCenter.default.post(name: .refreshAllData, object: nil)
        
        // Wait a moment and clear error if no new errors occurred
        try? await Task.sleep(nanoseconds: 1_000_000_000)
        
        if recoveryAttempts >= maxRecoveryAttempts {
            logger.info("Sync recovery completed after \(self.recoveryAttempts) attempts")
            await MainActor.run {
                clearError()
            }
        }
    }
    
    private func attemptPlaidRecovery() async {
        // Post notification to refresh Plaid connection
        NotificationCenter.default.post(name: .refreshPlaidConnection, object: nil)
        
        // Wait and clear error
        try? await Task.sleep(nanoseconds: 2_000_000_000)
        
        logger.info("Plaid recovery attempt completed")
        await MainActor.run {
            clearError()
        }
    }
}

// MARK: - Notification Names

extension Notification.Name {
    static let refreshAllData = Notification.Name("refreshAllData")
    static let clearAppCache = Notification.Name("clearAppCache")
    static let reconnectPlaid = Notification.Name("reconnectPlaid")
    static let refreshPlaidConnection = Notification.Name("refreshPlaidConnection")
    static let requestLocationPermission = Notification.Name("requestLocationPermission")
    static let contactSupport = Notification.Name("contactSupport")
}
