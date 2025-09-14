//
//  SpendConscienceAPIService.swift
//  SpendConscience
//
//  Service for connecting to the Plaid-Inkeep integration server
//

import Foundation
import Combine
import OSLog

/// Response model for the SpendConscience API
struct SpendConscienceResponse: Codable {
    let success: Bool
    let data: SpendConscienceData?
    let error: String?
}

/// Main data payload from the API
struct SpendConscienceData: Codable {
    let query: String
    let userId: String
    let response: String
    let agentFlow: [AgentFlowStep]
    let plaidData: PlaidDataSummary?
    let timestamp: String
    let mode: String
}

/// Agent workflow step
struct AgentFlowStep: Codable, Identifiable {
    let agent: String
    let action: String
    
    var id: String { "\(agent)-\(action)" }
}

/// Plaid data summary from the server
struct PlaidDataSummary: Codable {
    let accounts: [ServerAccount]
    let spendingByCategory: [String: Double]
    let totalSpending: Double
    let availableFunds: Double
}

/// Account information from server
struct ServerAccount: Codable, Identifiable {
    let id: String
    let name: String
    let type: String
    let subtype: String
    let availableBalance: Double
    let currentBalance: Double
}

/// Request model for asking financial questions
struct FinancialQuestionRequest: Codable {
    let query: String
    let userId: String
    let accessToken: String?
    
    init(query: String, userId: String = "ios-user", accessToken: String? = nil) {
        self.query = query
        self.userId = userId
        self.accessToken = accessToken
    }
}

/// Service errors
enum SpendConscienceAPIError: Error, LocalizedError {
    case invalidURL
    case noData
    case decodingError(String)
    case networkError(String)
    case serverError(String)
    case invalidResponse
    
    var errorDescription: String? {
        switch self {
        case .invalidURL:
            return "Invalid server URL"
        case .noData:
            return "No data received from server"
        case .decodingError(let message):
            return "Failed to decode response: \(message)"
        case .networkError(let message):
            return "Network error: \(message)"
        case .serverError(let message):
            return "Server error: \(message)"
        case .invalidResponse:
            return "Invalid response from server"
        }
    }
}

/// Main service class for interacting with the SpendConscience API
@MainActor
class SpendConscienceAPIService: ObservableObject {
    
    // MARK: - Published Properties
    
    @Published var isLoading: Bool = false
    @Published var currentResponse: SpendConscienceData?
    @Published var currentError: SpendConscienceAPIError?
    @Published var isConnected: Bool = false
    @Published var lastQuery: String = ""
    
    // MARK: - Private Properties
    
    private let baseURL: String
    private let session: URLSession
    private let encoder: JSONEncoder = {
        let e = JSONEncoder()
        e.keyEncodingStrategy = .convertToSnakeCase
        return e
    }()
    private let decoder: JSONDecoder = {
        let d = JSONDecoder()
        d.keyDecodingStrategy = .convertFromSnakeCase
        return d
    }()
    private let logger = Logger(subsystem: "SpendConscience", category: "APIService")
    
    // MARK: - Initialization
    
    init(baseURL: String? = nil) {
        // Use provided URL or load from configuration
        if let baseURL = baseURL {
            self.baseURL = baseURL
        } else {
            self.baseURL = ConfigurationLoader.getString("SpendConscienceAPIURL") ?? "http://localhost:4001"
        }
        
        let config = URLSessionConfiguration.default
        config.timeoutIntervalForRequest = 30
        config.timeoutIntervalForResource = 60
        self.session = URLSession(configuration: config)
        
        logger.info("SpendConscienceAPIService initialized with base URL: \(self.baseURL, privacy: .private)")
    }
    
    // MARK: - Public Methods
    
    /// Tests connection to the server
    func testConnection() async {
        logger.debug("Testing connection…")
        
        isLoading = true
        currentError = nil
        
        do {
            guard let url = makeURL("health") else {
                throw SpendConscienceAPIError.invalidURL
            }
            
            let (_, response) = try await session.data(from: url)
            
            guard let httpResponse = response as? HTTPURLResponse else {
                throw SpendConscienceAPIError.invalidResponse
            }
            
            if httpResponse.statusCode == 200 {
                isConnected = true
                logger.info("Connection successful")
            } else {
                throw SpendConscienceAPIError.networkError("HTTP \(httpResponse.statusCode)")
            }
            
        } catch {
            isConnected = false
            currentError = error as? SpendConscienceAPIError ?? .networkError(error.localizedDescription)
            logger.error("Connection failed: \(error.localizedDescription, privacy: .public)")
        }
        
        isLoading = false
    }
    
    /// Asks a financial question to the AI agents
    func askFinancialQuestion(_ query: String, userId: String = "ios-user") async -> SpendConscienceData? {
        logger.debug("Asking financial question")
        
        isLoading = true
        defer { isLoading = false }
        currentError = nil
        lastQuery = query
        
        do {
            guard let url = makeURL("ask") else {
                throw SpendConscienceAPIError.invalidURL
            }
            
            let request = FinancialQuestionRequest(query: query, userId: userId)
            let requestData = try encoder.encode(request)
            
            // Debug: Log the request being sent
            if let requestString = String(data: requestData, encoding: .utf8) {
                logger.debug("Sending request: \(requestString, privacy: .public)")
                print("🟡 DEBUG: Sending request: \(requestString)")
            }
            
            var urlRequest = URLRequest(url: url)
            urlRequest.httpMethod = "POST"
            urlRequest.setValue("application/json", forHTTPHeaderField: "Content-Type")
            urlRequest.httpBody = requestData
            
            let (data, response) = try await session.data(for: urlRequest)
            
            guard let httpResponse = response as? HTTPURLResponse else {
                throw SpendConscienceAPIError.invalidResponse
            }
            
            // Debug: Log the response
            logger.debug("Response status: \(httpResponse.statusCode)")
            print("🟡 DEBUG: Response status: \(httpResponse.statusCode)")
            if let responseString = String(data: data, encoding: .utf8) {
                logger.debug("Response data: \(responseString, privacy: .public)")
                print("🟡 DEBUG: Response data length: \(responseString.count)")
                print("🟡 DEBUG: Response data: \(String(responseString.prefix(200)))...")
            }
            
            if 200...299 ~= httpResponse.statusCode {
                // Debug: Check if data is empty
                if data.isEmpty {
                    logger.error("Received empty data despite 200 status code")
                    print("🔴 DEBUG: Received empty data despite 200 status code")
                    throw SpendConscienceAPIError.noData
                }
                
                print("🟡 DEBUG: About to decode JSON response...")
                let apiResponse = try decoder.decode(SpendConscienceResponse.self, from: data)
                print("🟢 DEBUG: Successfully decoded JSON response!")
                
                if apiResponse.success, let data = apiResponse.data {
                    currentResponse = data
                    logger.info("Received response from \(data.agentFlow.count) agents")
                    return data
                } else {
                    let errorMessage = apiResponse.error ?? "Unknown server error"
                    throw SpendConscienceAPIError.serverError(errorMessage)
                }
            } else if 400...499 ~= httpResponse.statusCode {
                // Client errors - usually user input related
                if let errorData = try? decoder.decode([String: String].self, from: data),
                   let message = errorData["error"] {
                    throw SpendConscienceAPIError.serverError(message)
                } else {
                    throw SpendConscienceAPIError.serverError("Client error (HTTP \(httpResponse.statusCode))")
                }
            } else {
                // Server errors (5xx)
                throw SpendConscienceAPIError.networkError("Server error (HTTP \(httpResponse.statusCode))")
            }
            
        } catch let error as DecodingError {
            let apiError = SpendConscienceAPIError.decodingError("Failed to parse server response")
            currentError = apiError
            logger.error("Decoding error: \(error.localizedDescription, privacy: .public)")
            print("🔴 DEBUG: Decoding error details: \(error)")
            print("🔴 DEBUG: Decoding error localized: \(error.localizedDescription)")
        } catch let error as URLError {
            currentError = SpendConscienceAPIError.networkError(error.localizedDescription)
            logger.error("Network error: \(error.localizedDescription, privacy: .public)")
        } catch let error as SpendConscienceAPIError {
            currentError = error
            logger.error("API error: \(error.localizedDescription, privacy: .public)")
        } catch {
            let apiError = SpendConscienceAPIError.networkError(error.localizedDescription)
            currentError = apiError
            logger.error("Unexpected error: \(error.localizedDescription, privacy: .public)")
        }
        
        return nil
    }
    
    /// Clears the current error
    func clearError() {
        currentError = nil
    }
    
    /// Clears the current response
    func clearResponse() {
        currentResponse = nil
        lastQuery = ""
    }
    
    // MARK: - Convenience Methods
    
    /// Asks about affordability of a specific amount
    func askAffordability(amount: Double, description: String = "purchase") async -> SpendConscienceData? {
        let query = "Can I afford a $\(String(format: "%.2f", amount)) \(description)?"
        return await askFinancialQuestion(query)
    }
    
    /// Asks for budget analysis
    func askBudgetAnalysis() async -> SpendConscienceData? {
        return await askFinancialQuestion("How is my budget this month?")
    }
    
    /// Asks for spending analysis
    func askSpendingAnalysis() async -> SpendConscienceData? {
        return await askFinancialQuestion("What are my largest expenses this week?")
    }
    
    /// Asks for financial advice
    func askFinancialAdvice() async -> SpendConscienceData? {
        return await askFinancialQuestion("What financial advice do you have for me?")
    }
    
    // MARK: - Helper Methods
    
    /// Formats agent flow for display
    func formatAgentFlow(_ agentFlow: [AgentFlowStep]) -> String {
        return agentFlow.map { "• \($0.agent): \($0.action)" }.joined(separator: "\n")
    }
    
    /// Gets the primary recommendation from the response
    func getPrimaryRecommendation() -> String? {
        guard let response = currentResponse else { return nil }
        
        // Extract the first line or key insight from the response
        let lines = response.response.components(separatedBy: "\n")
        return lines.first?.trimmingCharacters(in: .whitespacesAndNewlines)
    }
    
    /// Gets the available funds if present in Plaid data
    func getAvailableFunds() -> Double? {
        return currentResponse?.plaidData?.availableFunds
    }
    
    /// Gets spending by category
    func getSpendingByCategory() -> [String: Double]? {
        return currentResponse?.plaidData?.spendingByCategory
    }
    
    // MARK: - Status Methods
    
    /// Gets a human-readable status of the service
    var serviceStatus: String {
        var status = "SpendConscience API Status:\n"
        status += "  Connected: \(isConnected ? "✅" : "❌")\n"
        status += "  Loading: \(isLoading ? "🔄" : "✅")\n"
        status += "  Error: \(currentError?.localizedDescription ?? "None")\n"
        status += "  Last Query: \(lastQuery.isEmpty ? "None" : lastQuery)\n"
        status += "  Response: \(currentResponse != nil ? "Available" : "None")"
        return status
    }
    
    /// Logs the current service status
    func logServiceStatus() {
        logger.debug("Service Status - Connected: \(self.isConnected), Loading: \(self.isLoading), Error: \(self.currentError?.localizedDescription ?? "None"), Last Query: \(self.lastQuery.isEmpty ? "None" : "Present"), Response: \(self.currentResponse != nil ? "Available" : "None")")
    }
}

// MARK: - URL Helpers
private extension SpendConscienceAPIService {
    func makeURL(_ path: String) -> URL? {
        guard let base = URL(string: baseURL) else { return nil }
        return base.appendingPathComponent(path)
    }
}

// MARK: - Preview Helpers

#if DEBUG
extension SpendConscienceAPIService {
    static let preview: SpendConscienceAPIService = {
        let service = SpendConscienceAPIService(baseURL: "http://localhost:4001")
        service.isConnected = true
        service.currentResponse = SpendConscienceData(
            query: "Can I afford a $50 dinner?",
            userId: "preview-user",
            response: "✅ Yes, you can easily afford this $50 expense! It represents only 4% of your available funds.",
            agentFlow: [
                AgentFlowStep(agent: "Budget Analyzer", action: "Analyzed real Plaid spending data"),
                AgentFlowStep(agent: "Affordability Agent", action: "Made decision using real account balances"),
                AgentFlowStep(agent: "Financial Coach", action: "Generated personalized advice")
            ],
            plaidData: PlaidDataSummary(
                accounts: [
                    ServerAccount(id: "acc_1", name: "Checking", type: "depository", subtype: "checking", availableBalance: 2456.78, currentBalance: 2456.78)
                ],
                spendingByCategory: ["Food and Drink": 1245.67, "Transportation": 456.23],
                totalSpending: 3704.35,
                availableFunds: 11402.01
            ),
            timestamp: "2025-09-14T09:11:51.100Z",
            mode: "plaid-integration"
        )
        return service
    }()
}
#endif
