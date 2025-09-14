//
//  SpendConscienceAPIService.swift
//  SpendConscience
//
//  Service for connecting to the Plaid-Inkeep integration server
//

import Foundation
import Combine
import OSLog
import CoreLocation

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
    let lat: Double?
    let lng: Double?
    
    init(query: String, userId: String = "ios-user", accessToken: String? = nil, lat: Double? = nil, lng: Double? = nil) {
        self.query = query
        self.userId = userId
        self.accessToken = accessToken
        self.lat = lat
        self.lng = lng
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
    case locationDenied
    case locationUnavailable
    case invalidLocationData
    
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
        case .locationDenied:
            return "Location access denied. Please enable location services to get restaurant recommendations."
        case .locationUnavailable:
            return "Location services are unavailable. Restaurant recommendations require location access."
        case .invalidLocationData:
            return "Invalid location data. Please try again."
        }
    }
}

/// Main service class for interacting with the SpendConscience API
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
    private let backendDataDecoder: JSONDecoder = {
        let d = JSONDecoder()
        d.keyDecodingStrategy = .convertFromSnakeCase
        d.dateDecodingStrategy = .iso8601
        return d
    }()
    private let logger = Logger(subsystem: "SpendConscience", category: "APIService")
    private let networkErrorHandler: NetworkErrorHandler
    private let locationManager: LocationManager?
    
    // MARK: - Initialization
    
    init(baseURL: String? = nil, locationManager: LocationManager? = nil) {
        // Initialize network error handler
        self.networkErrorHandler = NetworkErrorHandler()
        
        // Initialize location manager
        self.locationManager = locationManager
        
        // Determine and validate the base URL first
        let configuredURL: String
        if let baseURL = baseURL {
            configuredURL = baseURL
        } else {
            configuredURL = ConfigurationLoader.getAPIURL()
        }
        
        // Validate URL format and set final baseURL exactly once
        let resolvedBaseURL: String
        if let url = URL(string: configuredURL) {
            // Enhance base URL resolution to default to HTTPS for non-localhost hosts
            if let host = url.host, !host.contains("localhost") && !host.contains("127.0.0.1") {
                // For non-localhost hosts, ensure HTTPS is used
                if url.scheme == "http" {
                    var components = URLComponents(url: url, resolvingAgainstBaseURL: false)
                    components?.scheme = "https"
                    resolvedBaseURL = components?.url?.absoluteString ?? configuredURL
                    logger.warning("Upgraded HTTP to HTTPS for non-localhost URL: \(resolvedBaseURL, privacy: .private)")
                } else if url.scheme == "https" {
                    resolvedBaseURL = configuredURL
                } else if url.scheme == nil {
                    // No scheme provided, default to HTTPS for non-localhost
                    resolvedBaseURL = "https://\(configuredURL)"
                    logger.info("Added HTTPS scheme to URL: \(resolvedBaseURL, privacy: .private)")
                } else {
                    resolvedBaseURL = configuredURL
                }
                
                // Validate that scheme is HTTPS in production
                #if !DEBUG
                if let finalURL = URL(string: resolvedBaseURL), finalURL.scheme != "https" {
                    logger.error("Production build requires HTTPS for non-localhost URLs. URL: \(resolvedBaseURL, privacy: .private)")
                }
                #endif
            } else {
                // For localhost, allow HTTP
                resolvedBaseURL = configuredURL
            }
        } else {
            resolvedBaseURL = "http://localhost:4001" // Final fallback for invalid URLs
        }
        self.baseURL = resolvedBaseURL
        
        // Initialize session with enhanced configuration
        let config = URLSessionConfiguration.default
        config.timeoutIntervalForRequest = networkErrorHandler.connectionQuality.recommendedTimeout
        config.timeoutIntervalForResource = 60
        self.session = URLSession(configuration: config)
        
        // Now we can safely use self for logging since all properties are initialized
        if let providedURL = baseURL {
            logger.info("SpendConscienceAPIService initialized with provided URL: \(providedURL, privacy: .private)")
        } else {
            // Validate configuration and log warnings if using fallback
            let validation = ConfigurationLoader.validateConfiguration()
            if !validation.isValid {
                logger.warning("Configuration validation failed. Using fallback URL.")
                validation.errors.forEach { error in
                    logger.warning("Configuration error: \(error, privacy: .public)")
                }
            }
            
            if self.baseURL.contains("localhost") {
                logger.warning("Using localhost fallback URL. Add SpendConscienceAPIURL to Config.Development.plist to use deployed backend.")
            } else {
                logger.info("Using configured production API URL: \(self.baseURL, privacy: .private)")
            }
            
            if configuredURL != self.baseURL {
                logger.error("Invalid API URL format: \(configuredURL, privacy: .private). Using fallback.")
            }
        }
        
        logger.info("SpendConscienceAPIService initialized successfully with network monitoring and location services")
    }
    
    // MARK: - Public Methods
    
    /// Tests connection to the server
    func testConnection() async {
        await testConnectionWithRetry()
    }
    
    /// Asks a financial question to the AI agents
    func askFinancialQuestion(_ query: String, userId: String = "ios-user") async -> SpendConscienceData? {
        logger.debug("Asking financial question")
        
        await MainActor.run {
            isLoading = true
            currentError = nil
            lastQuery = query
        }
        
        defer {
            Task { @MainActor in
                isLoading = false
            }
        }
        
        return await performRequestWithRetry(endpoint: "ask") {
            return try await self.buildAndExecuteRequest(query: query, userId: userId, coordinates: nil)
        }
    }
    
    /// Clears the current error
    func clearError() {
        Task { @MainActor in
            currentError = nil
        }
    }
    
    /// Clears the current response
    func clearResponse() {
        Task { @MainActor in
            currentResponse = nil
            lastQuery = ""
        }
    }
    
    // MARK: - Location-Aware Methods
    
    /// Asks a financial question with location data for restaurant alternatives
    func askWithLocation(_ query: String, coordinates: CLLocationCoordinate2D? = nil, userId: String = "ios-user") async -> SpendConscienceData? {
        logger.debug("Asking financial question with location")
        
        var finalCoordinates = coordinates
        
        // If no coordinates provided, try to get current location
        if finalCoordinates == nil {
            do {
                if let location = try await getCurrentLocationIfNeeded() {
                    finalCoordinates = location.coordinate
                }
            } catch {
                // Handle location errors but continue without location
                if let locationError = error as? LocationManager.LocationError {
                    await MainActor.run {
                        switch locationError {
                        case .denied:
                            currentError = .locationDenied
                        case .unavailable:
                            currentError = .locationUnavailable
                        default:
                            currentError = .invalidLocationData
                        }
                    }
                }
                logger.warning("Failed to get location, proceeding without: \(error.localizedDescription)")
            }
        }
        
        return await performRequestWithRetry {
            return try await self.makeLocationAwareRequest(query: query, coordinates: finalCoordinates, userId: userId)
        }
    }
    
    /// Gets current location if location services are available
    private func getCurrentLocationIfNeeded() async throws -> CLLocation? {
        guard let locationManager = locationManager else {
            throw LocationManager.LocationError.unavailable
        }
        
        // Check if location permission is already granted
        if await locationManager.checkLocationPermission() {
            return try await locationManager.getCurrentLocation()
        } else {
            // Request permission using async method
            let status = await locationManager.requestWhenInUseAuthorizationAsync()
            
            switch status {
            case .authorizedWhenInUse, .authorizedAlways:
                return try await locationManager.getCurrentLocation()
            case .denied, .restricted:
                throw LocationManager.LocationError.denied
            default:
                throw LocationManager.LocationError.unavailable
            }
        }
    }
    
    /// Makes a location-aware API request
    private func makeLocationAwareRequest(query: String, coordinates: CLLocationCoordinate2D?, userId: String) async throws -> SpendConscienceData {
        // Validate coordinates if provided
        if let coordinates = coordinates {
            try validateCoordinates(coordinates)
        }
        
        return try await buildAndExecuteRequest(query: query, userId: userId, coordinates: coordinates)
    }
    
    /// Validates coordinate ranges
    private func validateCoordinates(_ coordinates: CLLocationCoordinate2D) throws {
        // Validate latitude range (-90 to 90)
        guard coordinates.latitude >= -90.0 && coordinates.latitude <= 90.0 else {
            throw SpendConscienceAPIError.invalidLocationData
        }
        
        // Validate longitude range (-180 to 180)
        guard coordinates.longitude >= -180.0 && coordinates.longitude <= 180.0 else {
            throw SpendConscienceAPIError.invalidLocationData
        }
        
        // Check for invalid coordinates (0,0 might be invalid in some contexts)
        if coordinates.latitude == 0.0 && coordinates.longitude == 0.0 {
            logger.warning("Coordinates (0,0) detected - may be invalid location")
        }
    }
    
    // MARK: - Backend Data Methods
    
    /// Fetches transaction data from the backend
    func fetchTransactionData(startDate: Date? = nil, endDate: Date? = nil, category: String? = nil) async -> [BackendTransaction] {
        logger.debug("Fetching transaction data")
        
        var query = "Please provide my transaction history as structured JSON data"
        
        if let startDate = startDate, let endDate = endDate {
            let formatter = DateFormatter()
            formatter.dateStyle = .medium
            query += " from \(formatter.string(from: startDate)) to \(formatter.string(from: endDate))"
        } else if let startDate = startDate {
            let formatter = DateFormatter()
            formatter.dateStyle = .medium
            query += " since \(formatter.string(from: startDate))"
        } else {
            query += " for this month"
        }
        
        if let category = category {
            query += " for \(category) category"
        }
        
        query += ". Format the response as JSON with transaction objects containing id, amount, description, category, date, and accountId fields."
        
        if let response = await askFinancialQuestion(query) {
            return parseTransactionData(from: response)
        }
        
        return []
    }
    
    /// Fetches budget insights from the backend
    func fetchBudgetInsights(category: String? = nil) async -> [BackendBudget] {
        logger.debug("Fetching budget insights")
        
        let query = category != nil ? "Show me my budget analysis for \(category!) as structured JSON data" : "Show me my budget analysis for this month as structured JSON data with budget objects containing id, category, monthly_limit, current_spent, utilization_percentage, period, start_date, and end_date fields."
        
        if let response = await askFinancialQuestion(query) {
            logger.debug("Received response for budget insights, parsing...")
            return parseBudgetData(from: response)
        } else {
            logger.debug("No response received for budget insights")
        }
        
        return []
    }
    
    /// Fetches spending insights over different timeframes
    func fetchSpendingInsights(timeframe: String = "month") async -> SpendConscienceData? {
        logger.debug("Fetching spending insights")
        
        let query = "What are my spending patterns for this \(timeframe)?"
        return await askFinancialQuestion(query)
    }
    
    /// Searches for restaurant alternatives using location
    func searchRestaurantAlternatives(query: String, coordinates: CLLocationCoordinate2D? = nil, maxPrice: Int? = nil) async -> [RestaurantAlternative] {
        logger.debug("Searching restaurant alternatives")
        
        var searchQuery = query
        if let maxPrice = maxPrice {
            searchQuery += " under $\(maxPrice)"
        }
        searchQuery += " - find me cheaper alternatives nearby"
        
        if let response = await askWithLocation(searchQuery, coordinates: coordinates) {
            return parseRestaurantAlternatives(from: response)
        }
        
        return []
    }
    
    // MARK: - Response Parsing Methods
    
    /// Parses transaction data from API response
    private func parseTransactionData(from response: SpendConscienceData) -> [BackendTransaction] {
        logger.debug("Parsing transaction data from response")
        
        // First try to extract JSON from the response string
        if let jsonData = extractJSONFromResponse(response.response) {
            do {
                let backendResponse = try backendDataDecoder.decode(BackendDataResponse.self, from: jsonData)
                let transactions = backendResponse.transactions ?? []
                logger.info("Successfully parsed \(transactions.count) transactions from JSON")
                return transactions.filter { $0.isValid }
            } catch {
                logger.debug("Failed to decode JSON transaction data, trying plaid_data: \(error.localizedDescription)")
            }
        }
        
        // Fallback: Generate transactions from plaid_data spending categories
        if let plaidData = response.plaidData {
            logger.debug("Generating transactions from plaid_data spending categories")
            return generateTransactionsFromPlaidData(plaidData)
        }
        
        logger.debug("No transaction data found in response")
        return []
    }
    
    /// Generates mock transactions from Plaid spending data
    private func generateTransactionsFromPlaidData(_ plaidData: PlaidDataSummary) -> [BackendTransaction] {
        var transactions: [BackendTransaction] = []
        let calendar = Calendar.current
        let now = Date()
        
        // Generate transactions for each spending category
        for (categoryName, totalAmount) in plaidData.spendingByCategory {
            // Create 2-4 transactions per category to simulate realistic spending
            let transactionCount = Int.random(in: 2...4)
            let baseAmount = totalAmount / Double(transactionCount)
            
            for i in 0..<transactionCount {
                // Generate random dates within the current month
                let daysAgo = Int.random(in: 1...28)
                let transactionDate = calendar.date(byAdding: .day, value: -daysAgo, to: now) ?? now
                
                // Vary the amount slightly
                let variation = Double.random(in: 0.7...1.3)
                let amount = baseAmount * variation
                
                // Generate realistic descriptions based on category
                let description = generateDescriptionForCategory(categoryName, index: i)
                
                // Map category name to our enum
                let mappedCategory = mapCategoryName(categoryName)
                
                // Use first account ID if available
                let accountId = plaidData.accounts.first?.id ?? "default_account"
                
                let transaction = BackendTransaction(
                    id: UUID().uuidString,
                    amount: amount,
                    description: description,
                    category: mappedCategory,
                    date: transactionDate,
                    accountId: accountId,
                    merchantName: nil,
                    isoCurrencyCode: "USD",
                    accountName: plaidData.accounts.first?.name
                )
                
                transactions.append(transaction)
            }
        }
        
        logger.info("Generated \(transactions.count) transactions from plaid spending data")
        return transactions.sorted { $0.date > $1.date }
    }
    
    /// Generates realistic descriptions for different categories
    private func generateDescriptionForCategory(_ category: String, index: Int) -> String {
        switch category.lowercased() {
        case "food and drink", "food":
            let restaurants = ["Starbucks", "McDonald's", "Chipotle", "Local Cafe", "Pizza Palace", "Subway"]
            return restaurants[index % restaurants.count]
        case "transportation":
            let transport = ["Uber", "Gas Station", "Metro Card", "Parking Meter", "Lyft", "Bus Pass"]
            return transport[index % transport.count]
        case "entertainment":
            let entertainment = ["Netflix", "Movie Theater", "Spotify", "Concert Tickets", "Gaming", "Books"]
            return entertainment[index % entertainment.count]
        case "shopping":
            let shopping = ["Amazon", "Target", "Walmart", "Online Store", "Department Store", "Grocery Store"]
            return shopping[index % shopping.count]
        case "bills":
            let bills = ["Electric Bill", "Internet Bill", "Phone Bill", "Rent", "Insurance", "Subscription"]
            return bills[index % bills.count]
        default:
            return "\(category) Purchase #\(index + 1)"
        }
    }
    
    /// Maps category names from Plaid to our TransactionCategory enum
    private func mapCategoryName(_ categoryName: String) -> String {
        switch categoryName.lowercased() {
        case "food and drink", "food":
            return "dining"
        case "transportation":
            return "transportation"
        case "entertainment":
            return "entertainment"
        case "shopping":
            return "shopping"
        case "bills":
            return "utilities"
        default:
            return "other"
        }
    }
    
    /// Parses budget data from API response
    private func parseBudgetData(from response: SpendConscienceData) -> [BackendBudget] {
        logger.debug("Parsing budget data from response")
        
        // First, let's log the raw response to see what we're working with
        #if DEBUG
        print("🟡 DEBUG: Raw budget response: \(response.response)")
        #endif
        
        // Try to extract JSON from the response string
        guard let jsonData = extractJSONFromResponse(response.response) else {
            logger.debug("No JSON data found in response for budgets")
            return []
        }
        
        // Log the extracted JSON for debugging
        if let jsonString = String(data: jsonData, encoding: .utf8) {
            logger.debug("Extracted JSON for budget parsing: \(jsonString, privacy: .private)")
            #if DEBUG
            print("🟡 DEBUG: Extracted JSON for budget parsing: \(jsonString)")
            #endif
        }
        
        do {
            let backendResponse = try backendDataDecoder.decode(BackendDataResponse.self, from: jsonData)
            let budgets = backendResponse.budgets ?? []
            logger.info("Successfully parsed \(budgets.count) budgets")
            return budgets.filter { $0.isValid }
        } catch let decodingError {
            logger.error("Failed to decode budget data: \(decodingError.localizedDescription)")
            #if DEBUG
            print("🔴 DEBUG: Failed to decode budget data: \(decodingError)")
            if let decodingError = decodingError as? DecodingError {
                switch decodingError {
                case .dataCorrupted(let context):
                    print("🔴 DEBUG: Data corrupted: \(context)")
                case .keyNotFound(let key, let context):
                    print("🔴 DEBUG: Key not found: \(key) in \(context)")
                case .typeMismatch(let type, let context):
                    print("🔴 DEBUG: Type mismatch: expected \(type) in \(context)")
                case .valueNotFound(let type, let context):
                    print("🔴 DEBUG: Value not found: expected \(type) in \(context)")
                @unknown default:
                    print("🔴 DEBUG: Unknown decoding error")
                }
            }
            #endif
            
            // Try alternative parsing approaches
            return parseBudgetDataFallback(from: jsonData, originalResponse: response.response)
        }
    }
    
    /// Fallback budget parsing method for non-standard responses
    private func parseBudgetDataFallback(from jsonData: Data, originalResponse: String) -> [BackendBudget] {
        logger.debug("Attempting fallback budget parsing")
        
        // Try parsing as a simple array of budgets
        do {
            let budgets = try backendDataDecoder.decode([BackendBudget].self, from: jsonData)
            logger.info("Successfully parsed \(budgets.count) budgets using array fallback")
            return budgets.filter { $0.isValid }
        } catch {
            logger.debug("Array fallback failed: \(error.localizedDescription)")
        }
        
        // Try parsing with more lenient field requirements
        do {
            let flexibleBudgets = try parseBudgetDataFlexible(from: jsonData)
            if !flexibleBudgets.isEmpty {
                logger.info("Successfully parsed \(flexibleBudgets.count) budgets using flexible parsing")
                return flexibleBudgets
            }
        } catch {
            logger.debug("Flexible parsing failed: \(error.localizedDescription)")
        }
        
        // If all else fails, try to generate budgets from spending data in the response
        if originalResponse.contains("spending") || originalResponse.contains("budget") {
            logger.debug("Attempting to generate budgets from response text")
            return generateBudgetsFromResponseText(originalResponse)
        }
        
        logger.debug("All budget parsing approaches failed")
        return []
    }
    
    /// Flexible budget parsing that handles missing or differently named fields
    private func parseBudgetDataFlexible(from jsonData: Data) throws -> [BackendBudget] {
        // Define a flexible budget structure
        struct FlexibleBudget: Codable {
            let id: String?
            let category: String?
            let monthlyLimit: Double?
            let currentSpent: Double?
            let utilizationPercentage: Double?
            let period: String?
            let startDate: String?
            let endDate: String?
            
            // Alternative field names
            let monthly_limit: Double?
            let current_spent: Double?
            let utilization_percentage: Double?
            let start_date: String?
            let end_date: String?
            
            enum CodingKeys: String, CodingKey {
                case id, category, period
                case monthlyLimit = "monthlyLimit"
                case currentSpent = "currentSpent"
                case utilizationPercentage = "utilizationPercentage"
                case startDate = "startDate"
                case endDate = "endDate"
                case monthly_limit = "monthly_limit"
                case current_spent = "current_spent"
                case utilization_percentage = "utilization_percentage"
                case start_date = "start_date"
                case end_date = "end_date"
            }
            
            func toBackendBudget() -> BackendBudget? {
                guard let category = category else {
                    return nil
                }
                
                let budgetId = id ?? UUID().uuidString
                
                let monthlyLimitValue = monthlyLimit ?? monthly_limit ?? 1000.0
                let currentSpentValue = currentSpent ?? current_spent ?? 0.0
                let utilizationValue = utilizationPercentage ?? utilization_percentage ?? (currentSpentValue / monthlyLimitValue)
                
                let dateFormatter = ISO8601DateFormatter()
                let startDateValue = startDate ?? start_date
                let endDateValue = endDate ?? end_date
                
                let start = startDateValue.flatMap { dateFormatter.date(from: $0) } ?? Date()
                let end = endDateValue.flatMap { dateFormatter.date(from: $0) } ?? Calendar.current.date(byAdding: .month, value: 1, to: start) ?? Date()
                
                return BackendBudget(
                    id: budgetId,
                    category: category,
                    monthlyLimit: monthlyLimitValue,
                    currentSpent: currentSpentValue,
                    utilizationPercentage: utilizationValue,
                    period: period ?? "monthly",
                    startDate: start,
                    endDate: end
                )
            }
        }
        
        // Try parsing as flexible budget array
        let flexibleBudgets = try JSONDecoder().decode([FlexibleBudget].self, from: jsonData)
        return flexibleBudgets.compactMap { $0.toBackendBudget() }
    }
    
    /// Generate budgets from response text when structured data isn't available
    private func generateBudgetsFromResponseText(_ responseText: String) -> [BackendBudget] {
        logger.debug("Generating budgets from response text")
        
        // This is a simple fallback that creates default budgets
        // In a real implementation, you might parse the text for budget insights
        let defaultCategories = ["dining", "transportation", "entertainment", "shopping", "utilities"]
        var budgets: [BackendBudget] = []
        
        for category in defaultCategories {
            let budget = BackendBudget(
                id: UUID().uuidString,
                category: category,
                monthlyLimit: 500.0, // Default monthly limit
                currentSpent: 0.0,   // Default to zero spent
                utilizationPercentage: 0.0,
                period: "monthly",
                startDate: Calendar.current.dateInterval(of: .month, for: Date())?.start ?? Date(),
                endDate: Calendar.current.dateInterval(of: .month, for: Date())?.end ?? Date()
            )
            budgets.append(budget)
        }
        
        logger.info("Generated \(budgets.count) default budgets from response text")
        return budgets
    }
    
    /// Parses restaurant alternatives from API response
    private func parseRestaurantAlternatives(from response: SpendConscienceData) -> [RestaurantAlternative] {
        logger.debug("Parsing restaurant alternatives from response")
        
        // Try to extract JSON from the response string
        guard let jsonData = extractJSONFromResponse(response.response) else {
            logger.debug("No JSON data found in response for restaurants")
            return []
        }
        
        do {
            let backendResponse = try backendDataDecoder.decode(BackendDataResponse.self, from: jsonData)
            let restaurants = backendResponse.restaurantAlternatives ?? []
            logger.info("Successfully parsed \(restaurants.count) restaurant alternatives")
            return restaurants.filter { $0.isValid }
        } catch {
            logger.error("Failed to decode restaurant data: \(error.localizedDescription)")
            return []
        }
    }
    
    /// Extracts JSON data from response string
    private func extractJSONFromResponse(_ responseString: String) -> Data? {
        // Look for JSON blocks in the response (common patterns)
        let jsonPatterns = [
            "```json\\s*([\\s\\S]*?)```",  // JSON code blocks
            "\\{[\\s\\S]*\\}",             // JSON objects
            "\\[[\\s\\S]*\\]"              // JSON arrays
        ]
        
        for pattern in jsonPatterns {
            if let regex = try? NSRegularExpression(pattern: pattern, options: [.caseInsensitive]) {
                let range = NSRange(location: 0, length: responseString.count)
                if let match = regex.firstMatch(in: responseString, options: [], range: range) {
                    let matchRange = match.range(at: match.numberOfRanges > 1 ? 1 : 0)
                    if let swiftRange = Range(matchRange, in: responseString) {
                        let jsonString = String(responseString[swiftRange])
                        return jsonString.data(using: .utf8)
                    }
                }
            }
        }
        
        // If no JSON patterns found, try to parse the entire response as JSON
        return responseString.data(using: .utf8)
    }
    
    // MARK: - Enhanced Network Methods
    
    /// Performs a request with retry logic using NetworkErrorHandler
    private func performRequestWithRetry<T>(endpoint: String = "ask", operation: @escaping () async throws -> T) async -> T? {
        let startTime = Date()
        
        do {
            let configuration: NetworkErrorHandler.RetryConfiguration = baseURL.contains("localhost") ? .default : .serverless
            
            let result = try await networkErrorHandler.performRequestWithRetry(configuration: configuration) {
                return try await operation()
            }
            
            let duration = Date().timeIntervalSince(startTime)
            networkErrorHandler.logRequestPerformance(
                endpoint: endpoint,
                duration: duration,
                success: true
            )
            
            return result
        } catch {
            let duration = Date().timeIntervalSince(startTime)
            networkErrorHandler.logRequestPerformance(
                endpoint: endpoint,
                duration: duration,
                success: false,
                error: error
            )
            
            // Convert network errors to API errors
            await MainActor.run {
                if let networkError = error as? NetworkError {
                    switch networkError {
                    case .noInternetConnection:
                        currentError = .networkError("No internet connection")
                    case .serverUnavailable:
                        currentError = .serverError("Server unavailable")
                    case .timeout:
                        currentError = .networkError("Request timed out")
                    default:
                        currentError = .networkError(networkError.localizedDescription)
                    }
                } else {
                    currentError = .networkError(networkErrorHandler.userFriendlyMessage(for: error))
                }
            }
            
            logger.error("Request failed after retries: \(error.localizedDescription)")
            return nil
        }
    }
    
    /// Shared method to build and execute API requests
    private func buildAndExecuteRequest(query: String, userId: String, coordinates: CLLocationCoordinate2D?) async throws -> SpendConscienceData {
        guard let url = makeURL("ask") else {
            throw SpendConscienceAPIError.invalidURL
        }
        
        let request = FinancialQuestionRequest(
            query: query,
            userId: userId,
            accessToken: nil,
            lat: coordinates?.latitude,
            lng: coordinates?.longitude
        )
        
        let requestData = try encoder.encode(request)
        
        // Debug: Log the request being sent
        if let requestString = String(data: requestData, encoding: .utf8) {
            logger.debug("Sending request: \(requestString, privacy: .private)")
            #if DEBUG
            print("🟡 DEBUG: Sending request: \(requestString)")
            #endif
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
        #if DEBUG
        print("🟡 DEBUG: Response status: \(httpResponse.statusCode)")
        #endif
        if let responseString = String(data: data, encoding: .utf8) {
            logger.debug("Response data: \(responseString, privacy: .private)")
            #if DEBUG
            print("🟡 DEBUG: Response data length: \(responseString.count)")
            print("🟡 DEBUG: Response data: \(String(responseString.prefix(200)))...")
            #endif
        }
        
        if 200...299 ~= httpResponse.statusCode {
            // Debug: Check if data is empty
            if data.isEmpty {
                logger.error("Received empty data despite 200 status code")
                #if DEBUG
                print("🔴 DEBUG: Received empty data despite 200 status code")
                #endif
                throw SpendConscienceAPIError.noData
            }
            
            #if DEBUG
            print("🟡 DEBUG: About to decode JSON response...")
            #endif
            let apiResponse = try decoder.decode(SpendConscienceResponse.self, from: data)
            #if DEBUG
            print("🟢 DEBUG: Successfully decoded JSON response!")
            #endif
            
            if apiResponse.success, let responseData = apiResponse.data {
                await MainActor.run {
                    currentResponse = responseData
                }
                logger.info("Received response from \(responseData.agentFlow.count) agents")
                return responseData
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
        } else if httpResponse.statusCode >= 500 || httpResponse.statusCode == 429 || httpResponse.statusCode == 408 {
            // Server errors (5xx), rate limiting (429), and timeouts (408) - should be retried
            throw NSError(domain: "HTTPError", code: httpResponse.statusCode, userInfo: nil)
        } else {
            // Other errors
            throw SpendConscienceAPIError.networkError("HTTP error (\(httpResponse.statusCode))")
        }
    }
    
    // MARK: - Enhanced Connection Testing
    
    /// Tests connection with retry logic
    func testConnectionWithRetry() async {
        logger.debug("Testing connection with retry logic")
        
        await MainActor.run {
            isLoading = true
            currentError = nil
        }
        
        let result = await performRequestWithRetry {
            guard let url = self.makeURL("health") else {
                throw SpendConscienceAPIError.invalidURL
            }
            
            let (_, response) = try await self.session.data(from: url)
            
            guard let httpResponse = response as? HTTPURLResponse else {
                throw SpendConscienceAPIError.invalidResponse
            }
            
            if httpResponse.statusCode == 200 {
                return true
            } else if httpResponse.statusCode >= 500 || httpResponse.statusCode == 429 || httpResponse.statusCode == 408 {
                // Server errors (5xx), rate limiting (429), and timeouts (408) - should be retried
                throw NSError(domain: "HTTPError", code: httpResponse.statusCode, userInfo: nil)
            } else {
                throw SpendConscienceAPIError.networkError("HTTP \(httpResponse.statusCode)")
            }
        }
        
        await MainActor.run {
            isConnected = result == true
            isLoading = false
        }
        
        if isConnected {
            logger.info("Connection successful with retry logic")
        } else {
            logger.error("Connection failed even with retries")
        }
    }
    
    // MARK: - Convenience Methods
    
    /// Asks about affordability of a specific amount
    func askAffordability(amount: Double, description: String = "purchase") async -> SpendConscienceData? {
        let query = "Can I afford a $\(String(format: "%.2f", amount)) \(description)?"
        return await askFinancialQuestion(query)
    }
    
    /// Asks about affordability with location for restaurant alternatives
    func askAffordabilityWithLocation(amount: Double, description: String = "dinner", coordinates: CLLocationCoordinate2D? = nil) async -> SpendConscienceData? {
        let query = "Can I afford a $\(String(format: "%.2f", amount)) \(description)? If not, find me cheaper alternatives nearby."
        return await askWithLocation(query, coordinates: coordinates)
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
    @MainActor var serviceStatus: String {
        var status = "SpendConscience API Status:\n"
        status += "  Connected: \(isConnected ? "✅" : "❌")\n"
        status += "  Loading: \(isLoading ? "🔄" : "✅")\n"
        status += "  Network: \(networkErrorHandler.connectionQuality.description)\n"
        
        // Add location status
        if let locationManager = locationManager {
            let authStatus = locationManager.authorizationStatus
            let locationStatusText: String
            switch authStatus {
            case .notDetermined:
                locationStatusText = "Not requested"
            case .denied, .restricted:
                locationStatusText = "Denied"
            case .authorizedWhenInUse:
                locationStatusText = "Authorized (when in use)"
            case .authorizedAlways:
                locationStatusText = "Authorized (always)"
            @unknown default:
                locationStatusText = "Unknown"
            }
            status += "  Location: \(locationStatusText)\n"
        } else {
            status += "  Location: Unavailable\n"
        }
        
        status += "  Error: \(currentError?.localizedDescription ?? "None")\n"
        status += "  Last Query: \(lastQuery.isEmpty ? "None" : lastQuery)\n"
        status += "  Response: \(currentResponse != nil ? "Available" : "None")"
        return status
    }
    
    /// Logs the current service status
    func logServiceStatus() {
        logger.debug("Service Status - Connected: \(self.isConnected), Loading: \(self.isLoading), Error: \(self.currentError?.localizedDescription ?? "None"), Last Query: \(self.lastQuery.isEmpty ? "None" : "Present"), Response: \(self.currentResponse != nil ? "Available" : "None")")
    }
    
    // MARK: - Plaid Integration Methods
    
    /// Creates a link token for Plaid Link initialization
    /// - Parameter userId: User ID for token association
    /// - Returns: PlaidLinkTokenResponse containing the link token
    func createPlaidLinkToken(userId: String = "ios-user") async throws -> PlaidLinkTokenResponse {
        logger.info("Creating Plaid link token for user: \(userId)")
        
        guard let url = makeURL("/api/plaid/create_link_token") else {
            throw SpendConscienceAPIError.invalidURL
        }
        
        let request = PlaidLinkTokenRequest(userId: userId)
        
        var urlRequest = URLRequest(url: url)
        urlRequest.httpMethod = "POST"
        urlRequest.setValue("application/json", forHTTPHeaderField: "Content-Type")
        
        do {
            urlRequest.httpBody = try JSONEncoder().encode(request)
        } catch {
            logger.error("Failed to encode link token request: \(error.localizedDescription)")
            throw SpendConscienceAPIError.decodingError("Failed to encode request")
        }
        
        do {
            let (data, response) = try await URLSession.shared.data(for: urlRequest)
            
            if let httpResponse = response as? HTTPURLResponse {
                logger.debug("Link token response status: \(httpResponse.statusCode)")
                if httpResponse.statusCode != 200 {
                    throw SpendConscienceAPIError.serverError("HTTP \(httpResponse.statusCode)")
                }
            }
            
            let linkTokenResponse = try JSONDecoder().decode(PlaidLinkTokenResponse.self, from: data)
            logger.info("Successfully created link token")
            return linkTokenResponse
            
        } catch let error as DecodingError {
            logger.error("Failed to decode link token response: \(error.localizedDescription)")
            throw SpendConscienceAPIError.decodingError(error.localizedDescription)
        } catch {
            logger.error("Network error creating link token: \(error.localizedDescription)")
            throw SpendConscienceAPIError.networkError(error.localizedDescription)
        }
    }
    
    /// Exchanges a public token for an access token
    /// - Parameters:
    ///   - publicToken: Public token from Plaid Link
    ///   - userId: User ID for token association
    /// - Returns: PlaidTokenExchangeResponse containing the access token
    func exchangePlaidPublicToken(publicToken: String, userId: String = "ios-user") async throws -> PlaidTokenExchangeResponse {
        logger.info("Exchanging public token for access token for user: \(userId)")
        
        guard let url = makeURL("/api/plaid/exchange_public_token") else {
            throw SpendConscienceAPIError.invalidURL
        }
        
        let request = PlaidTokenExchangeRequest(publicToken: publicToken, userId: userId)
        
        var urlRequest = URLRequest(url: url)
        urlRequest.httpMethod = "POST"
        urlRequest.setValue("application/json", forHTTPHeaderField: "Content-Type")
        
        do {
            urlRequest.httpBody = try JSONEncoder().encode(request)
        } catch {
            logger.error("Failed to encode token exchange request: \(error.localizedDescription)")
            throw SpendConscienceAPIError.decodingError("Failed to encode request")
        }
        
        do {
            let (data, response) = try await URLSession.shared.data(for: urlRequest)
            
            if let httpResponse = response as? HTTPURLResponse {
                logger.debug("Token exchange response status: \(httpResponse.statusCode)")
                if httpResponse.statusCode != 200 {
                    throw SpendConscienceAPIError.serverError("HTTP \(httpResponse.statusCode)")
                }
            }
            
            let exchangeResponse = try JSONDecoder().decode(PlaidTokenExchangeResponse.self, from: data)
            logger.info("Successfully exchanged public token for access token")
            return exchangeResponse
            
        } catch let error as DecodingError {
            logger.error("Failed to decode token exchange response: \(error.localizedDescription)")
            throw SpendConscienceAPIError.decodingError(error.localizedDescription)
        } catch {
            logger.error("Network error exchanging token: \(error.localizedDescription)")
            throw SpendConscienceAPIError.networkError(error.localizedDescription)
        }
    }
    
    /// Fetches accounts for the user's linked Plaid item
    /// - Parameter userId: User ID to fetch accounts for
    /// - Returns: PlaidAccountsResponse containing account information
    func fetchPlaidAccounts(userId: String = "ios-user") async throws -> PlaidAccountsResponse {
        logger.info("Fetching Plaid accounts for user: \(userId)")
        
        guard let url = makeURL("/api/plaid/accounts") else {
            throw SpendConscienceAPIError.invalidURL
        }
        
        let request = PlaidAccountsRequest(userId: userId)
        
        var urlRequest = URLRequest(url: url)
        urlRequest.httpMethod = "POST"
        urlRequest.setValue("application/json", forHTTPHeaderField: "Content-Type")
        
        do {
            urlRequest.httpBody = try JSONEncoder().encode(request)
        } catch {
            logger.error("Failed to encode accounts request: \(error.localizedDescription)")
            throw SpendConscienceAPIError.decodingError("Failed to encode request")
        }
        
        do {
            let (data, response) = try await URLSession.shared.data(for: urlRequest)
            
            if let httpResponse = response as? HTTPURLResponse {
                logger.debug("Accounts response status: \(httpResponse.statusCode)")
                if httpResponse.statusCode != 200 {
                    throw SpendConscienceAPIError.serverError("HTTP \(httpResponse.statusCode)")
                }
            }
            
            let accountsResponse = try JSONDecoder().decode(PlaidAccountsResponse.self, from: data)
            logger.info("Successfully fetched \(accountsResponse.accounts.count) accounts")
            return accountsResponse
            
        } catch let error as DecodingError {
            logger.error("Failed to decode accounts response: \(error.localizedDescription)")
            throw SpendConscienceAPIError.decodingError(error.localizedDescription)
        } catch {
            logger.error("Network error fetching accounts: \(error.localizedDescription)")
            throw SpendConscienceAPIError.networkError(error.localizedDescription)
        }
    }
}

// MARK: - Plaid Request/Response Models

/// Request for creating a Plaid link token
struct PlaidLinkTokenRequest: Codable {
    let userId: String
}

/// Response containing a Plaid link token
struct PlaidLinkTokenResponse: Codable {
    let linkToken: String
    let expiration: String
    
    enum CodingKeys: String, CodingKey {
        case linkToken = "link_token"
        case expiration
    }
}

/// Request for exchanging a public token
struct PlaidTokenExchangeRequest: Codable {
    let publicToken: String
    let userId: String
    
    enum CodingKeys: String, CodingKey {
        case publicToken = "public_token"
        case userId
    }
}

/// Response from token exchange
struct PlaidTokenExchangeResponse: Codable {
    let accessToken: String
    let itemId: String
    
    enum CodingKeys: String, CodingKey {
        case accessToken = "access_token"
        case itemId = "item_id"
    }
}

/// Request for fetching accounts
struct PlaidAccountsRequest: Codable {
    let userId: String
}

/// Response containing Plaid accounts
struct PlaidAccountsResponse: Codable {
    let accounts: [PlaidAccountDetail]
}

/// Detailed account information from Plaid
struct PlaidAccountDetail: Codable, Identifiable {
    let id: String
    let name: String
    let type: String
    let subtype: String?
    let mask: String?
    let balance: PlaidAccountBalance
    
    enum CodingKeys: String, CodingKey {
        case id = "account_id"
        case name
        case type
        case subtype
        case mask
        case balance = "balances"
    }
}

/// Account balance information
struct PlaidAccountBalance: Codable {
    let available: Double?
    let current: Double
    let limit: Double?
    let isoCurrencyCode: String
    
    enum CodingKeys: String, CodingKey {
        case available
        case current
        case limit
        case isoCurrencyCode = "iso_currency_code"
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
