//
//  SpendConscienceTests.swift
//  SpendConscienceTests
//
//  Created by Sehej Jain on 9/13/25.
//

import Testing
import Foundation
@testable import SpendConscience

struct SpendConscienceTests {

    // MARK: - PlaidService Tests
    
    @Test func testPlaidServiceInitialization() async throws {
        let plaidService = PlaidService()
        
        await MainActor.run {
            #expect(!plaidService.isConnected)
            #expect(!plaidService.isLoading)
            #expect(plaidService.accounts.isEmpty)
            #expect(plaidService.transactions.isEmpty)
            #expect(plaidService.currentError == nil)
            // Note: accessToken and itemId are private - cannot test directly
        }
    }
    
    @Test func testPlaidConfigurationValidation() async throws {
        // Test that configuration has required properties
        #expect(PlaidConfiguration.clientId != nil)
        #expect(PlaidConfiguration.secret != nil)
        #expect(PlaidConfiguration.environment == .sandbox)
        #expect(!PlaidConfiguration.baseURL.isEmpty)
        
        // Note: products and countryCodes don't exist in PlaidConfiguration
        // These might be in PlaidService configuration
    }
    
    @Test func testPlaidErrorEnum() async throws {
        let invalidCredentialsError = PlaidError.invalidCredentials
        let networkError = PlaidError.networkError("Test network error")
        let invalidResponseError = PlaidError.invalidResponse
        let missingCredentialsError = PlaidError.missingCredentials  // or another appropriate case
        
        // Test error descriptions
        #expect(invalidCredentialsError.localizedDescription.contains("Invalid"))
        #expect(networkError.localizedDescription.contains("Network"))
        #expect(invalidResponseError.localizedDescription.contains("Invalid response"))
        #expect(missingCredentialsError.localizedDescription.contains("Missing"))
    }
    
    @Test func testPlaidModelsDecoding() async throws {
        // Test PlaidAccount decoding
        let accountJSON = """
        {
            "account_id": "test_account_id",
            "name": "Test Checking",
            "type": "depository",
            "subtype": "checking",
            "balances": {
                "current": 1000.50,
                "available": 950.25
            }
        }
        """
        
        let accountData = accountJSON.data(using: .utf8)!
        let account = try JSONDecoder().decode(PlaidAccount.self, from: accountData)
        
        #expect(account.id == "test_account_id")
        #expect(account.name == "Test Checking")
        #expect(account.type == .depository)
        #expect(account.subtype == .checking)
        #expect(account.balance.current == 1000.50)
        #expect(account.balance.available == 950.25)
    }
    
    @Test func testPlaidTransactionDecoding() async throws {
        // Test PlaidTransaction decoding
        let transactionJSON = """
        {
            "transaction_id": "test_transaction_id",
            "account_id": "test_account_id",
            "amount": 25.50,
            "date": "2024-01-15",
            "name": "Test Transaction",
            "merchant_name": "Test Merchant",
            "category": ["Food and Drink", "Restaurants"]
        }
        """
        
        let transactionData = transactionJSON.data(using: .utf8)!
        let transaction = try JSONDecoder().decode(PlaidTransaction.self, from: transactionData)
        
        #expect(transaction.id == "test_transaction_id")
        #expect(transaction.accountId == "test_account_id")
        #expect(transaction.amount == 25.50)
        // Date should be parsed properly from the JSON string
        let dateFormatter = DateFormatter()
        dateFormatter.dateFormat = "yyyy-MM-dd"
        let expectedDate = dateFormatter.date(from: "2024-01-15")!
        #expect(transaction.date == expectedDate)
        #expect(transaction.name == "Test Transaction")
        #expect(transaction.merchantName == "Test Merchant")
        #expect(transaction.category?.count == 2)
        #expect(transaction.category?.first == "Food and Drink")
    }
    
    @Test func testPlaidServiceRequestCreation() async throws {
        let plaidService = PlaidService()
        
        // Test sandbox public token creation request
        let publicTokenRequest = plaidService.createSandboxPublicTokenRequest()
        
        #expect(publicTokenRequest.url?.absoluteString.contains("sandbox/public_token/create") == true)
        #expect(publicTokenRequest.httpMethod == "POST")
        #expect(publicTokenRequest.value(forHTTPHeaderField: "Content-Type") == "application/json")
        
        // Verify request body contains required fields
        if let bodyData = publicTokenRequest.httpBody {
            let bodyJSON = try JSONSerialization.jsonObject(with: bodyData) as? [String: Any]
            #expect(bodyJSON?["client_id"] != nil)
            #expect(bodyJSON?["secret"] != nil)
            #expect(bodyJSON?["institution_id"] != nil)
            #expect(bodyJSON?["initial_products"] != nil)
        }
    }
    
    @Test func testPlaidServiceTokenExchangeRequest() async throws {
        let plaidService = PlaidService()
        let testPublicToken = "public-sandbox-test-token"
        
        let exchangeRequest = plaidService.createTokenExchangeRequest(publicToken: testPublicToken)
        
        #expect(exchangeRequest.url?.absoluteString.contains("item/public_token/exchange") == true)
        #expect(exchangeRequest.httpMethod == "POST")
        #expect(exchangeRequest.value(forHTTPHeaderField: "Content-Type") == "application/json")
        
        // Verify request body contains required fields
        if let bodyData = exchangeRequest.httpBody {
            let bodyJSON = try JSONSerialization.jsonObject(with: bodyData) as? [String: Any]
            #expect(bodyJSON?["client_id"] != nil)
            #expect(bodyJSON?["secret"] != nil)
            #expect(bodyJSON?["public_token"] as? String == testPublicToken)
        }
    }
    
    @Test func testPlaidServiceAccountsRequest() async throws {
        let plaidService = PlaidService()
        let testAccessToken = "access-sandbox-test-token"
        
        let accountsRequest = plaidService.createAccountsRequest(accessToken: testAccessToken)
        
        #expect(accountsRequest.url?.absoluteString.contains("accounts/get") == true)
        #expect(accountsRequest.httpMethod == "POST")
        #expect(accountsRequest.value(forHTTPHeaderField: "Content-Type") == "application/json")
        
        // Verify request body contains required fields
        if let bodyData = accountsRequest.httpBody {
            let bodyJSON = try JSONSerialization.jsonObject(with: bodyData) as? [String: Any]
            #expect(bodyJSON?["client_id"] != nil)
            #expect(bodyJSON?["secret"] != nil)
            #expect(bodyJSON?["access_token"] as? String == testAccessToken)
        }
    }
    
    @Test func testPlaidServiceTransactionsRequest() async throws {
        let plaidService = PlaidService()
        let testAccessToken = "access-sandbox-test-token"
        
        let transactionsRequest = plaidService.createTransactionsRequest(accessToken: testAccessToken)
        
        #expect(transactionsRequest.url?.absoluteString.contains("transactions/get") == true)
        #expect(transactionsRequest.httpMethod == "POST")
        #expect(transactionsRequest.value(forHTTPHeaderField: "Content-Type") == "application/json")
        
        // Verify request body contains required fields
        if let bodyData = transactionsRequest.httpBody {
            let bodyJSON = try JSONSerialization.jsonObject(with: bodyData) as? [String: Any]
            #expect(bodyJSON?["client_id"] != nil)
            #expect(bodyJSON?["secret"] != nil)
            #expect(bodyJSON?["access_token"] as? String == testAccessToken)
            #expect(bodyJSON?["start_date"] != nil)
            #expect(bodyJSON?["end_date"] != nil)
        }
    }
    
    @Test func testPlaidServiceDateFormatting() async throws {
        let plaidService = PlaidService()
        
        // Test date formatting
        let testDate = Date(timeIntervalSince1970: 1705276800) // 2024-01-15
        let formattedDate = plaidService.formatDateForPlaid(testDate)
        
        #expect(formattedDate == "2024-01-15")
    }
    
    @Test func testPlaidServiceStateManagement() async throws {
        let plaidService = PlaidService()
        
        // Test initial state
        #expect(!plaidService.isConnected)
        #expect(!plaidService.isLoading)
        #expect(plaidService.lastError == nil)
        
        // Test loading state
        await MainActor.run {
            plaidService.setLoading(true)
            #expect(plaidService.isLoading)
        }
        
        await MainActor.run {
            plaidService.setLoading(false)
            #expect(!plaidService.isLoading)
        }
        
        // Test error state
        let testError = PlaidError.invalidCredentials
        await MainActor.run {
            plaidService.setError(testError)
            #expect(plaidService.lastError != nil)
        }
        
        await MainActor.run {
            plaidService.clearError()
            #expect(plaidService.lastError == nil)
        }
    }
    
    // MARK: - TransactionStore Tests
    
    @Test func testTransactionStoreInitialization() async throws {
        let transactionStore = TransactionStore()
        
        #expect(!transactionStore.isLoading)
        #expect(transactionStore.lastError == nil)
    }
    
    @Test func testPlaidToSwiftDataConversion() async throws {
        let transactionStore = TransactionStore()
        
        // Create test Plaid transaction
        let plaidTransaction = PlaidTransaction(
            transactionId: "test_id",
            accountId: "test_account",
            amount: 25.50,
            date: "2024-01-15",
            name: "Test Transaction",
            merchantName: "Test Merchant",
            category: ["Food and Drink", "Restaurants"]
        )
        
        let swiftDataTransaction = transactionStore.convertPlaidTransaction(plaidTransaction)
        
        #expect(swiftDataTransaction.amount == 25.50)
        #expect(swiftDataTransaction.merchantName == "Test Merchant")
        #expect(swiftDataTransaction.category.rawValue == "Food and Drink")
        
        // Test date conversion
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd"
        let expectedDate = formatter.date(from: "2024-01-15")
        #expect(swiftDataTransaction.date.timeIntervalSince1970 == expectedDate?.timeIntervalSince1970)
    }
    
    @Test func testTransactionCategoryMapping() async throws {
        let transactionStore = TransactionStore()
        
        // Test various category mappings
        let foodCategory = transactionStore.mapPlaidCategoryToTransactionCategory(["Food and Drink", "Restaurants"])
        #expect(foodCategory == .dining)
        
        let transportCategory = transactionStore.mapPlaidCategoryToTransactionCategory(["Transportation", "Gas Stations"])
        #expect(transportCategory == .transportation)
        
        let shoppingCategory = transactionStore.mapPlaidCategoryToTransactionCategory(["Shops", "Retail"])
        #expect(shoppingCategory == .shopping)
        
        let unknownCategory = transactionStore.mapPlaidCategoryToTransactionCategory(["Unknown Category"])
        #expect(unknownCategory == .other)
        
        let emptyCategory = transactionStore.mapPlaidCategoryToTransactionCategory([])
        #expect(emptyCategory == .other)
    }
    
    // MARK: - Integration Tests
    
    @Test func testPlaidServiceErrorHandling() async throws {
        let plaidService = PlaidService()
        
        // Test network error handling
        let networkError = NSError(domain: NSURLErrorDomain, code: NSURLErrorNotConnectedToInternet, userInfo: nil)
        
        await MainActor.run {
            plaidService.handleNetworkError(networkError)
            #expect(plaidService.lastError != nil)
            #expect(!plaidService.isLoading)
        }
    }
    
    @Test func testPlaidServiceJSONParsing() async throws {
        let plaidService = PlaidService()
        
        // Test successful response parsing
        let successResponseJSON = """
        {
            "accounts": [
                {
                    "account_id": "test_account",
                    "name": "Test Account",
                    "type": "depository",
                    "subtype": "checking",
                    "balances": {
                        "current": 1000.0,
                        "available": 950.0
                    }
                }
            ]
        }
        """
        
        let responseData = successResponseJSON.data(using: .utf8)!
        let parsedResponse = try JSONDecoder().decode(PlaidAccountsResponse.self, from: responseData)
        
        #expect(parsedResponse.accounts.count == 1)
        #expect(parsedResponse.accounts.first?.name == "Test Account")
    }
    
    @Test func testPlaidServiceConfigurationValidation() async throws {
        let plaidService = PlaidService()
        
        // Test configuration validation
        let isValid = plaidService.validateConfiguration()
        #expect(isValid) // Should be true with default configuration
        
        // Test that service can create requests with valid configuration
        let request = plaidService.createSandboxPublicTokenRequest()
        #expect(request.url != nil)
        #expect(request.httpBody != nil)
    }
}

// MARK: - Test Extensions

extension PlaidService {
    func createSandboxPublicTokenRequest() -> URLRequest {
        let url = URL(string: "\(configuration.baseURL)/sandbox/public_token/create")!
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        
        let body: [String: Any] = [
            "client_id": configuration.clientId,
            "secret": configuration.secret,
            "institution_id": "ins_109508",
            "initial_products": configuration.products
        ]
        
        request.httpBody = try? JSONSerialization.data(withJSONObject: body)
        return request
    }
    
    func createTokenExchangeRequest(publicToken: String) -> URLRequest {
        let url = URL(string: "\(configuration.baseURL)/item/public_token/exchange")!
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        
        let body: [String: Any] = [
            "client_id": configuration.clientId,
            "secret": configuration.secret,
            "public_token": publicToken
        ]
        
        request.httpBody = try? JSONSerialization.data(withJSONObject: body)
        return request
    }
    
    func createAccountsRequest(accessToken: String) -> URLRequest {
        let url = URL(string: "\(configuration.baseURL)/accounts/get")!
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        
        let body: [String: Any] = [
            "client_id": configuration.clientId,
            "secret": configuration.secret,
            "access_token": accessToken
        ]
        
        request.httpBody = try? JSONSerialization.data(withJSONObject: body)
        return request
    }
    
    func createTransactionsRequest(accessToken: String) -> URLRequest {
        let url = URL(string: "\(configuration.baseURL)/transactions/get")!
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        
        let startDate = Calendar.current.date(byAdding: .day, value: -30, to: Date()) ?? Date()
        let endDate = Date()
        
        let body: [String: Any] = [
            "client_id": configuration.clientId,
            "secret": configuration.secret,
            "access_token": accessToken,
            "start_date": formatDateForPlaid(startDate),
            "end_date": formatDateForPlaid(endDate)
        ]
        
        request.httpBody = try? JSONSerialization.data(withJSONObject: body)
        return request
    }
    
    func formatDateForPlaid(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd"
        return formatter.string(from: date)
    }
    
    func validateConfiguration() -> Bool {
        return !configuration.clientId.isEmpty && 
               !configuration.secret.isEmpty && 
               !configuration.baseURL.isEmpty
    }
    
    func setLoading(_ loading: Bool) {
        isLoading = loading
    }
    
    func setError(_ error: PlaidError) {
        lastError = error
    }
    
    func clearError() {
        lastError = nil
    }
    
    func handleNetworkError(_ error: Error) {
        lastError = PlaidError.networkError(error)
        isLoading = false
    }
}

extension TransactionStore {
    func convertPlaidTransaction(_ plaidTransaction: PlaidTransaction) -> Transaction {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd"
        let date = formatter.date(from: plaidTransaction.date) ?? Date()
        
        return Transaction(
            amount: plaidTransaction.amount,
            category: mapPlaidCategoryToTransactionCategory(plaidTransaction.category ?? []),
            date: date,
            merchantName: plaidTransaction.merchantName ?? plaidTransaction.name,
            notes: nil
        )
    }
    
    func mapPlaidCategoryToTransactionCategory(_ plaidCategories: [String]) -> TransactionCategory {
        guard let primaryCategory = plaidCategories.first?.lowercased() else {
            return .other
        }
        
        switch primaryCategory {
        case "food and drink", "restaurants":
            return .dining
        case "transportation", "gas stations":
            return .transportation
        case "shops", "retail":
            return .shopping
        case "entertainment":
            return .entertainment
        case "healthcare":
            return .healthcare
        case "travel":
            return .travel
        case "groceries":
            return .groceries
        default:
            return .other
        }
    }
}
