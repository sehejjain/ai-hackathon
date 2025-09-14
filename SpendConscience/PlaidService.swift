//
//  PlaidService.swift
//  SpendConscience
//
//  Main Plaid service class for API integration
//

import Foundation
import Network

/// Main Plaid service class implementing ObservableObject pattern for SwiftUI integration
@MainActor
class PlaidService: ObservableObject {
    
    // MARK: - Published Properties
    
    /// Current connection status
    @Published var isConnected: Bool = false
    
    /// Loading state for API operations
    @Published var isLoading: Bool = false
    
    /// Current error state
    @Published var currentError: PlaidError?
    
    /// Available accounts
    @Published var accounts: [PlaidAccount] = []
    
    /// Recent transactions
    @Published var transactions: [PlaidTransaction] = []
    
    /// Service initialization status
    @Published var isInitialized: Bool = false
    
    // MARK: - Private Properties
    
    /// URLSession for API calls with standard SSL validation
    private lazy var urlSession: URLSession = {
        let configuration = URLSessionConfiguration.default
        configuration.timeoutIntervalForRequest = 30
        configuration.timeoutIntervalForResource = 60
        return URLSession(configuration: configuration)
    }()
    
    /// Network path monitor for connectivity
    private let networkMonitor = NWPathMonitor()
    
    /// Network monitoring queue
    private let networkQueue = DispatchQueue(label: "PlaidService.NetworkMonitor")
    
    /// Access token for authenticated API calls
    private var accessToken: String?
    
    /// Item ID from token exchange
    private var itemId: String?
    
    /// Date formatter for Plaid API dates (YYYY-MM-DD format)
    private let plaidDateFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd"
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.timeZone = TimeZone(secondsFromGMT: 0)
        return formatter
    }()
    
    /// JSON encoder for API requests
    private let jsonEncoder: JSONEncoder = {
        let encoder = JSONEncoder()
        encoder.keyEncodingStrategy = .useDefaultKeys
        encoder.dateEncodingStrategy = .formatted(PlaidService.createPlaidDateFormatter())
        return encoder
    }()
    
    /// JSON decoder for API responses
    private let jsonDecoder: JSONDecoder = {
        let decoder = JSONDecoder()
        decoder.keyDecodingStrategy = .useDefaultKeys
        decoder.dateDecodingStrategy = .formatted(PlaidService.createPlaidDateFormatter())
        return decoder
    }()
    
    /// Creates a DateFormatter for Plaid API date format
    private static func createPlaidDateFormatter() -> DateFormatter {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd"
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.timeZone = TimeZone(secondsFromGMT: 0)
        return formatter
    }
    
    // MARK: - Initialization
    
    init() {
        initializeService()
        startNetworkMonitoring()
    }
    
    deinit {
        networkMonitor.cancel()
    }
    
    // MARK: - Service Initialization
    
    /// Initializes the Plaid service with configuration validation
    private func initializeService() {
        print("🚀 PlaidService: Initializing service...")
        
        // Validate configuration
        guard PlaidConfiguration.validateCredentials() else {
            currentError = .missingCredentials
            print("❌ PlaidService: Initialization failed - missing credentials")
            return
        }
        
        // Log configuration status
        PlaidConfiguration.logConfiguration()
        
        isInitialized = true
        print("✅ PlaidService: Service initialized successfully")
    }
    
    // MARK: - Network Monitoring
    
    /// Starts monitoring network connectivity
    private func startNetworkMonitoring() {
        networkMonitor.pathUpdateHandler = { [weak self] path in
            DispatchQueue.main.async {
                self?.isConnected = path.status == .satisfied
                
                if path.status == .satisfied {
                    print("🌐 PlaidService: Network connection available")
                } else {
                    print("❌ PlaidService: Network connection unavailable")
                    self?.currentError = .noInternetConnection
                }
            }
        }
        
        networkMonitor.start(queue: networkQueue)
    }
    
    // MARK: - API Request Foundation
    
    /// Creates a base URL request for Plaid API endpoints
    private func createBaseRequest(endpoint: String, httpMethod: String = "POST") throws -> URLRequest {
        guard let url = URL(string: "\(PlaidConfiguration.baseURL)/\(endpoint)") else {
            throw PlaidError.invalidURL
        }
        
        var request = URLRequest(url: url)
        request.httpMethod = httpMethod
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue("application/json", forHTTPHeaderField: "Accept")
        request.setValue("SpendConscience/1.0", forHTTPHeaderField: "User-Agent")
        
        return request
    }
    
    /// Executes an API request with proper error handling
    private func executeRequest<T: Codable>(
        request: URLRequest,
        responseType: T.Type
    ) async throws -> T {
        do {
            let (data, response) = try await urlSession.data(for: request)
            
            guard let httpResponse = response as? HTTPURLResponse else {
                throw PlaidError.invalidResponse
            }
            
            print("📡 PlaidService: API Response Status: \(httpResponse.statusCode)")
            
            // Handle HTTP error status codes
            if httpResponse.statusCode >= 400 {
                if let errorResponse = try? jsonDecoder.decode(PlaidAPIError.self, from: data) {
                    throw PlaidError.apiError(code: errorResponse.errorCode, message: errorResponse.errorMessage)
                } else {
                    throw PlaidError.networkError("HTTP \(httpResponse.statusCode)")
                }
            }
            
            // Decode successful response
            do {
                let decodedResponse = try jsonDecoder.decode(responseType, from: data)
                return decodedResponse
            } catch {
                print("❌ PlaidService: Decoding error: \(error)")
                throw PlaidError.decodingError(error.localizedDescription)
            }
            
        } catch let error as PlaidError {
            throw error
        } catch {
            print("❌ PlaidService: Network error: \(error)")
            throw PlaidError.networkError(error.localizedDescription)
        }
    }
    
    // MARK: - API Methods
    
    /// Creates a sandbox public token for testing
    func createSandboxPublicToken() async throws -> String {
        guard isInitialized else {
            throw PlaidError.invalidConfiguration
        }
        
        print("🔑 PlaidService: Creating sandbox public token...")
        
        do {
            guard let clientId = PlaidConfiguration.clientId,
                  let secret = PlaidConfiguration.secret else {
                throw PlaidError.missingCredentials
            }
            
            let request = SandboxPublicTokenCreateRequest(
                clientId: clientId,
                secret: secret,
                institutionId: SandboxInstitutions.firstPlatypus,
                initialProducts: PlaidProducts.defaultSandbox,
                options: SandboxPublicTokenOptions.dynamicTransactions()
            )
            
            var urlRequest = try createBaseRequest(endpoint: "sandbox/public_token/create")
            urlRequest.httpBody = try jsonEncoder.encode(request)
            
            let response = try await executeRequest(
                request: urlRequest,
                responseType: SandboxPublicTokenCreateResponse.self
            )
            
            print("✅ PlaidService: Sandbox public token created successfully")
            return response.publicToken
            
        } catch {
            print("❌ PlaidService: Failed to create sandbox public token: \(error)")
            throw error
        }
    }
    
    /// Exchanges public token for access token
    func exchangePublicToken(_ publicToken: String) async throws -> (accessToken: String, itemId: String) {
        guard isInitialized else {
            throw PlaidError.invalidConfiguration
        }
        
        print("🔄 PlaidService: Exchanging public token for access token...")
        
        do {
            guard let clientId = PlaidConfiguration.clientId,
                  let secret = PlaidConfiguration.secret else {
                throw PlaidError.missingCredentials
            }
            
            let request = ItemPublicTokenExchangeRequest(
                clientId: clientId,
                secret: secret,
                publicToken: publicToken
            )
            
            var urlRequest = try createBaseRequest(endpoint: "item/public_token/exchange")
            urlRequest.httpBody = try jsonEncoder.encode(request)
            
            let response = try await executeRequest(
                request: urlRequest,
                responseType: ItemPublicTokenExchangeResponse.self
            )
            
            // Store tokens for future use
            self.accessToken = response.accessToken
            self.itemId = response.itemId
            
            print("✅ PlaidService: Token exchange completed successfully")
            return (accessToken: response.accessToken, itemId: response.itemId)
            
        } catch {
            print("❌ PlaidService: Failed to exchange public token: \(error)")
            throw error
        }
    }
    
    /// Creates custom sandbox transactions for testing
    func createSandboxTransactions() async throws {
        guard isInitialized else {
            throw PlaidError.invalidConfiguration
        }
        
        guard let accessToken = accessToken else {
            throw PlaidError.invalidCredentials
        }
        
        print("💰 PlaidService: Creating custom sandbox transactions...")
        
        do {
            guard let clientId = PlaidConfiguration.clientId,
                  let secret = PlaidConfiguration.secret else {
                throw PlaidError.missingCredentials
            }
            
            let today = Date()
            let yesterday = Calendar.current.date(byAdding: .day, value: -1, to: today) ?? today
            
            let dateFormatter = DateFormatter()
            dateFormatter.dateFormat = "yyyy-MM-dd"
            
            let customTransactions = [
                SandboxTransactionCreate(
                    amount: 12.34,
                    datePosted: dateFormatter.string(from: today),
                    dateTransacted: dateFormatter.string(from: today),
                    description: "Coffee Corner"
                ),
                SandboxTransactionCreate(
                    amount: 42.00,
                    datePosted: dateFormatter.string(from: yesterday),
                    dateTransacted: dateFormatter.string(from: yesterday),
                    description: "Gas & Go"
                )
            ]
            
            let request = SandboxTransactionsCreateRequest(
                clientId: clientId,
                secret: secret,
                accessToken: accessToken,
                transactions: customTransactions
            )
            
            var urlRequest = try createBaseRequest(endpoint: "sandbox/transactions/create")
            urlRequest.httpBody = try jsonEncoder.encode(request)
            
            let _ = try await executeRequest(
                request: urlRequest,
                responseType: SandboxTransactionsCreateResponse.self
            )
            
            print("✅ PlaidService: Created \(customTransactions.count) custom sandbox transactions")
            
        } catch {
            print("❌ PlaidService: Failed to create sandbox transactions: \(error)")
            throw error
        }
    }
    
    /// Fetches user accounts
    func fetchAccounts() async {
        guard isInitialized else {
            currentError = .invalidConfiguration
            return
        }
        
        guard let accessToken = accessToken else {
            currentError = .invalidCredentials
            print("❌ PlaidService: No access token available for fetchAccounts")
            return
        }
        
        isLoading = true
        defer { isLoading = false }
        currentError = nil
        
        print("📋 PlaidService: Fetching accounts...")
        
        do {
            guard let clientId = PlaidConfiguration.clientId,
                  let secret = PlaidConfiguration.secret else {
                currentError = .missingCredentials
                return
            }
            
            let request = AccountsGetRequest(
                clientId: clientId,
                secret: secret,
                accessToken: accessToken
            )
            
            var urlRequest = try createBaseRequest(endpoint: "accounts/get")
            urlRequest.httpBody = try jsonEncoder.encode(request)
            
            let response = try await executeRequest(
                request: urlRequest,
                responseType: AccountsResponse.self
            )
            
            self.accounts = response.accounts
            print("✅ PlaidService: Fetched \(response.accounts.count) accounts")
            
        } catch let error as PlaidError {
            handleError(error)
        } catch {
            handleError(.unknown(error.localizedDescription))
        }
    }
    
    /// Syncs transactions using the transactions/sync endpoint
    func fetchTransactions() async {
        guard isInitialized else {
            currentError = .invalidConfiguration
            return
        }
        
        guard let accessToken = accessToken else {
            currentError = .invalidCredentials
            print("❌ PlaidService: No access token available for fetchTransactions")
            return
        }
        
        isLoading = true
        defer { isLoading = false }
        currentError = nil
        
        print("� PlaidService: Syncing transactions...")
        
        do {
            guard let clientId = PlaidConfiguration.clientId,
                  let secret = PlaidConfiguration.secret else {
                currentError = .missingCredentials
                return
            }
            
            var allTransactions: [PlaidTransaction] = []
            var cursor: String? = nil
            var attempts = 0
            let maxAttempts = 6
            
            // Poll for transactions with retries (similar to Python example)
            repeat {
                attempts += 1
                print("🔄 PlaidService: Sync attempt \(attempts)/\(maxAttempts) (cursor: \(cursor ?? "nil"))")
                
                let request = TransactionsSyncRequest(
                    clientId: clientId,
                    secret: secret,
                    accessToken: accessToken,
                    cursor: cursor,
                    count: nil
                )
                
                var urlRequest = try createBaseRequest(endpoint: "transactions/sync")
                urlRequest.httpBody = try jsonEncoder.encode(request)
                
                let response = try await executeRequest(
                    request: urlRequest,
                    responseType: TransactionsSyncResponse.self
                )
                
                // Add new transactions
                allTransactions.append(contentsOf: response.added)
                
                // Update cursor for next iteration
                cursor = response.nextCursor
                
                print("📄 PlaidService: Added \(response.added.count) transactions (total: \(allTransactions.count))")
                
                // If we got transactions, break out of retry loop
                if !allTransactions.isEmpty {
                    break
                }
                
                // Wait before next attempt (like Python example)
                if attempts < maxAttempts {
                    try await Task.sleep(for: .seconds(5))
                }
                
            } while attempts < maxAttempts
            
            self.transactions = allTransactions
            
            if allTransactions.isEmpty {
                print("⚠️ PlaidService: No transactions found after \(attempts) attempts")
            } else {
                print("✅ PlaidService: Synced \(allTransactions.count) transactions successfully")
                
                // Print sample transactions like the Python example
                print("\n=== Added transactions ===")
                for transaction in allTransactions.prefix(10) {
                    let dateFormatter = DateFormatter()
                    dateFormatter.dateFormat = "yyyy-MM-dd"
                    print("\(dateFormatter.string(from: transaction.date)) - \(transaction.name): $\(transaction.amount)")
                }
                if allTransactions.count > 10 {
                    print("... and \(allTransactions.count - 10) more transactions")
                }
            }
            
        } catch let error as PlaidError {
            handleError(error)
        } catch {
            handleError(.unknown(error.localizedDescription))
        }
    }
    
    /// Initializes Plaid connection by creating sandbox token and exchanging it
    func initializePlaidConnection() async {
        guard isInitialized else {
            currentError = .invalidConfiguration
            return
        }
        
        isLoading = true
        currentError = nil
        
        print("🚀 PlaidService: Initializing Plaid connection...")
        
        do {
            // Step 1: Create sandbox public token
            let publicToken = try await createSandboxPublicToken()
            print("✅ PlaidService: Created public token")
            
            // Step 2: Exchange for access token
            let (accessToken, itemId) = try await exchangePublicToken(publicToken)
            print("✅ PlaidService: Exchanged for access token: \(String(accessToken.prefix(10)))...")
            
            // Step 3: Create custom sandbox transactions for immediate data
            try await createSandboxTransactions()
            
            // Step 4: Fetch initial data
            await fetchAccounts()
            await fetchTransactions()
            
            print("✅ PlaidService: Plaid connection initialized successfully")
            
        } catch let error as PlaidError {
            print("❌ PlaidService: PlaidError during initialization: \(error.localizedDescription)")
            handleError(error)
        } catch {
            print("❌ PlaidService: Unexpected error during initialization: \(error)")
            handleError(.unknown(error.localizedDescription))
        }
        
        isLoading = false
    }
    
    /// Refreshes all data
    func refreshData() async {
        print("🔄 PlaidService: Refreshing all data...")
        
        await fetchAccounts()
        await fetchTransactions()
        
        print("✅ PlaidService: Data refresh completed")
    }
    
    // MARK: - Error Handling
    
    /// Clears the current error state
    func clearError() {
        currentError = nil
    }
    
    /// Handles and logs errors appropriately
    private func handleError(_ error: PlaidError) {
        currentError = error
        isLoading = false
        
        print("❌ PlaidService: Error occurred - \(error.localizedDescription)")
        
        // Log additional context based on error type
        switch error {
        case .missingCredentials, .invalidConfiguration:
            print("   💡 Hint: Check your Info.plist for PLAID_SANDBOX_API and PLAID_CLIENT")
        case .networkError, .noInternetConnection:
            print("   💡 Hint: Check your internet connection")
        case .invalidCredentials, .expiredToken:
            print("   💡 Hint: Check your Plaid API credentials")
        default:
            break
        }
    }
}

// MARK: - Service State Management

extension PlaidService {
    
    /// Current service status for debugging
    var serviceStatus: String {
        var status = "PlaidService Status:\n"
        status += "  Initialized: \(isInitialized ? "✅" : "❌")\n"
        status += "  Connected: \(isConnected ? "✅" : "❌")\n"
        status += "  Loading: \(isLoading ? "🔄" : "✅")\n"
        status += "  Error: \(currentError?.localizedDescription ?? "None")\n"
        status += "  Accounts: \(accounts.count)\n"
        status += "  Transactions: \(transactions.count)"
        return status
    }
    
    /// Logs current service status
    func logServiceStatus() {
        print("📊 \(serviceStatus)")
    }
}
