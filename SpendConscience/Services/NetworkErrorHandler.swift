//
//  NetworkErrorHandler.swift
//  SpendConscience
//
//  Created by AI Assistant on 9/14/2025.
//

import Foundation
import Network

class NetworkErrorHandler: ObservableObject {
    @Published var isConnected = true
    @Published var connectionType: NWInterface.InterfaceType?
    
    private let monitor = NWPathMonitor()
    private let queue = DispatchQueue(label: "NetworkMonitor")
    
    // Retry configuration
    struct RetryConfiguration {
        let maxAttempts: Int
        let baseDelay: TimeInterval
        let maxDelay: TimeInterval
        let backoffMultiplier: Double
        
        static let `default` = RetryConfiguration(
            maxAttempts: 3,
            baseDelay: 1.0,
            maxDelay: 30.0,
            backoffMultiplier: 2.0
        )
        
        static let serverless = RetryConfiguration(
            maxAttempts: 4,
            baseDelay: 2.0,
            maxDelay: 45.0,
            backoffMultiplier: 2.5
        )
    }
    
    init() {
        startMonitoring()
    }
    
    deinit {
        monitor.cancel()
    }
    
    private func startMonitoring() {
        monitor.pathUpdateHandler = { [weak self] path in
            DispatchQueue.main.async {
                self?.isConnected = path.status == .satisfied
                self?.connectionType = path.availableInterfaces.first?.type
            }
        }
        monitor.start(queue: queue)
    }
    
    // MARK: - Error Analysis
    
    func shouldRetryError(_ error: Error) -> Bool {
        if let urlError = error as? URLError {
            switch urlError.code {
            case .timedOut, .cannotConnectToHost, .networkConnectionLost, .notConnectedToInternet:
                return true
            case .badServerResponse, .cannotParseResponse:
                return true
            case .userCancelledAuthentication, .userAuthenticationRequired:
                return false
            default:
                return false
            }
        }
        
        // Handle SpendConscienceAPIError by extracting HTTP status codes
        if let apiError = error as? SpendConscienceAPIError {
            switch apiError {
            case .serverError(let message), .networkError(let message):
                // Try to extract HTTP status code from error message using regex
                if let statusCode = extractHTTPStatusCode(from: message) {
                    return statusCode >= 500 || statusCode == 408 || statusCode == 429
                }
                // If no status code found, retry network errors but not server errors
                if case .networkError = apiError {
                    return true
                } else {
                    return false
                }
            default:
                return false
            }
        }
        
        let nsError = error as NSError
        // HTTP status codes that should be retried
        if nsError.domain == "HTTPError" {
            let statusCode = nsError.code
            return statusCode >= 500 || statusCode == 408 || statusCode == 429
        }
        
        return false
    }
    
    private func extractHTTPStatusCode(from message: String) -> Int? {
        // Look for HTTP status codes in error messages
        let patterns = [
            "HTTP (\\d{3})",           // "HTTP 500"
            "status code (\\d{3})",    // "status code 500"
            "error \\((\\d{3})\\)",    // "error (500)"
            "\\((\\d{3})\\)"           // "(500)"
        ]
        
        for pattern in patterns {
            if let regex = try? NSRegularExpression(pattern: pattern, options: [.caseInsensitive]) {
                let range = NSRange(location: 0, length: message.count)
                if let match = regex.firstMatch(in: message, options: [], range: range) {
                    let statusRange = match.range(at: 1)
                    if let swiftRange = Range(statusRange, in: message) {
                        let statusString = String(message[swiftRange])
                        return Int(statusString)
                    }
                }
            }
        }
        
        return nil
    }
    
    func isServerlessError(_ error: Error) -> Bool {
        if let urlError = error as? URLError {
            return urlError.code == .timedOut || urlError.code == .cannotConnectToHost
        }
        
        let nsError = error as NSError
        // Check for cold start indicators
        if nsError.domain == "HTTPError" && nsError.code == 504 {
            return true // Gateway timeout often indicates cold start
        }
        
        return false
    }
    
    func calculateRetryDelay(attempt: Int, configuration: RetryConfiguration = .default) -> TimeInterval {
        let exponentialDelay = configuration.baseDelay * pow(configuration.backoffMultiplier, Double(attempt - 1))
        let jitteredDelay = exponentialDelay * (0.5 + Double.random(in: 0...0.5)) // Add jitter
        return min(jitteredDelay, configuration.maxDelay)
    }
    
    // MARK: - Retry Logic
    
    func performRequestWithRetry<T>(
        configuration: RetryConfiguration = .default,
        operation: @escaping () async throws -> T
    ) async throws -> T {
        var lastError: Error?
        
        for attempt in 1...configuration.maxAttempts {
            do {
                return try await operation()
            } catch {
                lastError = error
                
                // Don't retry on the last attempt
                if attempt == configuration.maxAttempts {
                    break
                }
                
                // Check if we should retry this error
                guard shouldRetryError(error) else {
                    throw error
                }
                
                // Calculate delay for this attempt
                let delay = calculateRetryDelay(attempt: attempt, configuration: configuration)
                
                // Log retry attempt
                print("Request failed (attempt \(attempt)/\(configuration.maxAttempts)): \(error.localizedDescription)")
                print("Retrying in \(delay) seconds...")
                
                // Wait before retrying
                try await Task.sleep(nanoseconds: UInt64(delay * 1_000_000_000))
            }
        }
        
        // If we get here, all attempts failed
        throw lastError ?? NetworkError.maxRetriesExceeded
    }
    
    // MARK: - User-Friendly Error Messages
    
    func userFriendlyMessage(for error: Error) -> String {
        if !isConnected {
            return "No internet connection. Please check your network settings and try again."
        }
        
        if let urlError = error as? URLError {
            switch urlError.code {
            case .timedOut:
                if isServerlessError(error) {
                    return "Server is starting up. Please try again in a moment."
                }
                return "Request timed out. Please try again."
            case .cannotConnectToHost:
                return "Cannot connect to server. Please check your internet connection."
            case .networkConnectionLost:
                return "Network connection lost. Please try again."
            case .notConnectedToInternet:
                return "No internet connection available."
            case .badServerResponse:
                return "Server returned an invalid response. Please try again."
            case .cannotParseResponse:
                return "Unable to process server response. Please try again."
            default:
                return "Network error occurred. Please try again."
            }
        }
        
        let nsError = error as NSError
        if nsError.domain == "HTTPError" {
            let statusCode = nsError.code
            switch statusCode {
            case 400:
                return "Invalid request. Please check your input and try again."
            case 401:
                return "Authentication required. Please log in again."
            case 403:
                return "Access denied. You don't have permission for this action."
            case 404:
                return "Service not found. Please try again later."
            case 429:
                return "Too many requests. Please wait a moment and try again."
            case 500...599:
                return "Server error occurred. Please try again in a few moments."
            default:
                return "An error occurred (Code: \(statusCode)). Please try again."
            }
        }
        
        return error.localizedDescription
    }
    
    // MARK: - Connection Quality
    
    var connectionQuality: ConnectionQuality {
        guard isConnected else { return .none }
        
        switch connectionType {
        case .wifi:
            return .excellent
        case .cellular:
            return .good
        case .wiredEthernet:
            return .excellent
        default:
            return .poor
        }
    }
    
    enum ConnectionQuality {
        case none
        case poor
        case good
        case excellent
        
        var description: String {
            switch self {
            case .none:
                return "No connection"
            case .poor:
                return "Poor connection"
            case .good:
                return "Good connection"
            case .excellent:
                return "Excellent connection"
            }
        }
        
        var recommendedTimeout: TimeInterval {
            switch self {
            case .none:
                return 10.0
            case .poor:
                return 30.0
            case .good:
                return 20.0
            case .excellent:
                return 15.0
            }
        }
    }
}

// MARK: - Network Errors
enum NetworkError: LocalizedError {
    case maxRetriesExceeded
    case noInternetConnection
    case serverUnavailable
    case invalidResponse
    case timeout
    
    var errorDescription: String? {
        switch self {
        case .maxRetriesExceeded:
            return "Maximum retry attempts exceeded. Please try again later."
        case .noInternetConnection:
            return "No internet connection available."
        case .serverUnavailable:
            return "Server is currently unavailable. Please try again later."
        case .invalidResponse:
            return "Received invalid response from server."
        case .timeout:
            return "Request timed out. Please try again."
        }
    }
}

// MARK: - Request Performance Monitoring
extension NetworkErrorHandler {
    func logRequestPerformance(
        endpoint: String,
        duration: TimeInterval,
        success: Bool,
        error: Error? = nil
    ) {
        let status = success ? "SUCCESS" : "FAILED"
        let errorInfo = error?.localizedDescription ?? "N/A"
        
        print("API Performance - Endpoint: \(endpoint), Duration: \(String(format: "%.2f", duration))s, Status: \(status), Error: \(errorInfo)")
        
        // In a production app, you might want to send this to analytics
        // Analytics.track("api_request", properties: [
        //     "endpoint": endpoint,
        //     "duration": duration,
        //     "success": success,
        //     "error": errorInfo,
        //     "connection_type": connectionType?.debugDescription ?? "unknown"
        // ])
    }
}
