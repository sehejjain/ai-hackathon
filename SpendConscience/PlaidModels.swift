//
//  PlaidModels.swift
//  SpendConscience
//
//  Core data models for Plaid API integration
//

import Foundation

// MARK: - Date Formatting

private extension DateFormatter {
    static let plaidYYYYMMDD: DateFormatter = {
        let df = DateFormatter()
        df.calendar = Calendar(identifier: .gregorian)
        df.locale = Locale(identifier: "en_US_POSIX")
        df.timeZone = TimeZone(secondsFromGMT: 0)
        df.dateFormat = "yyyy-MM-dd"
        return df
    }()
}

// MARK: - Transaction Model

/// Represents a financial transaction from Plaid API
struct PlaidTransaction: Codable, Identifiable, Equatable {
    let id: String
    let amount: Double
    let date: Date
    let name: String
    let category: [String]?
    let accountId: String
    let merchantName: String?
    let pending: Bool?
    let transactionType: TransactionType?
    
    enum CodingKeys: String, CodingKey {
        case id = "transaction_id"
        case amount
        case date
        case name = "name"
        case category
        case accountId = "account_id"
        case merchantName = "merchant_name"
        case pending
        case transactionType = "transaction_type"
    }
    
    /// Custom decoder to handle various date formats and optional fields
    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        
        id = try container.decode(String.self, forKey: .id)
        amount = try container.decode(Double.self, forKey: .amount)
        name = try container.decode(String.self, forKey: .name)
        category = try container.decodeIfPresent([String].self, forKey: .category)
        accountId = try container.decode(String.self, forKey: .accountId)
        merchantName = try container.decodeIfPresent(String.self, forKey: .merchantName)
        pending = try container.decodeIfPresent(Bool.self, forKey: .pending)
        transactionType = try container.decodeIfPresent(TransactionType.self, forKey: .transactionType)
        
        // Handle date decoding - Plaid returns dates in YYYY-MM-DD format
        let dateString = try container.decode(String.self, forKey: .date)
        let formatter = DateFormatter.plaidYYYYMMDD
        if let parsedDate = formatter.date(from: dateString) {
            date = parsedDate
        } else {
            throw DecodingError.dataCorrupted(DecodingError.Context(
                codingPath: decoder.codingPath,
                debugDescription: "Invalid date format: \(dateString)"
            ))
        }
    }
    
    /// Custom encoder
    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        
        try container.encode(id, forKey: .id)
        try container.encode(amount, forKey: .amount)
        try container.encode(name, forKey: .name)
        try container.encodeIfPresent(category, forKey: .category)
        try container.encode(accountId, forKey: .accountId)
        try container.encodeIfPresent(merchantName, forKey: .merchantName)
        try container.encodeIfPresent(pending, forKey: .pending)
        try container.encodeIfPresent(transactionType, forKey: .transactionType)
        
        // Encode date as string
        try container.encode(DateFormatter.plaidYYYYMMDD.string(from: date), forKey: .date)
    }
    
    /// Transaction type enumeration
    enum TransactionType: Codable, CaseIterable, Equatable {
        case digital
        case place
        case special
        case unresolved
        case unknown(String)
        
        static var allCases: [TransactionType] {
            return [.digital, .place, .special, .unresolved]
        }
        
        init(from decoder: Decoder) throws {
            let container = try decoder.singleValueContainer()
            
            // Handle case where transaction_type might be null
            if container.decodeNil() {
                self = .unresolved
                return
            }
            
            let rawValue = try container.decode(String.self)
            
            switch rawValue {
            case "digital": self = .digital
            case "place": self = .place
            case "special": self = .special
            case "unresolved": self = .unresolved
            default: self = .unknown(rawValue)
            }
        }
        
        func encode(to encoder: Encoder) throws {
            var container = encoder.singleValueContainer()
            switch self {
            case .digital: try container.encode("digital")
            case .place: try container.encode("place")
            case .special: try container.encode("special")
            case .unresolved: try container.encode("unresolved")
            case .unknown(let value): try container.encode(value)
            }
        }
        
        static func == (lhs: TransactionType, rhs: TransactionType) -> Bool {
            switch (lhs, rhs) {
            case (.digital, .digital), (.place, .place), (.special, .special), (.unresolved, .unresolved):
                return true
            case (.unknown(let lhsValue), .unknown(let rhsValue)):
                return lhsValue == rhsValue
            default:
                return false
            }
        }
    }
}

// MARK: - Account Model

/// Represents a financial account from Plaid API
struct PlaidAccount: Codable, Identifiable, Equatable {
    let id: String
    let name: String
    let type: AccountType
    let subtype: AccountSubtype?
    let balance: AccountBalance
    let mask: String?
    let officialName: String?
    
    enum CodingKeys: String, CodingKey {
        case id = "account_id"
        case name
        case type
        case subtype
        case balance = "balances"
        case mask
        case officialName = "official_name"
    }
    
    /// Account type enumeration
    enum AccountType: Codable, CaseIterable, Equatable {
        case depository
        case credit
        case loan
        case investment
        case other
        case unknown(String)
        
        static var allCases: [AccountType] {
            return [.depository, .credit, .loan, .investment, .other]
        }
        
        init(from decoder: Decoder) throws {
            let container = try decoder.singleValueContainer()
            let rawValue = try container.decode(String.self)
            
            switch rawValue {
            case "depository": self = .depository
            case "credit": self = .credit
            case "loan": self = .loan
            case "investment": self = .investment
            case "other": self = .other
            default: self = .unknown(rawValue)
            }
        }
        
        func encode(to encoder: Encoder) throws {
            var container = encoder.singleValueContainer()
            switch self {
            case .depository: try container.encode("depository")
            case .credit: try container.encode("credit")
            case .loan: try container.encode("loan")
            case .investment: try container.encode("investment")
            case .other: try container.encode("other")
            case .unknown(let value): try container.encode(value)
            }
        }
        
        static func == (lhs: AccountType, rhs: AccountType) -> Bool {
            switch (lhs, rhs) {
            case (.depository, .depository), (.credit, .credit), (.loan, .loan), (.investment, .investment), (.other, .other):
                return true
            case (.unknown(let lhsValue), .unknown(let rhsValue)):
                return lhsValue == rhsValue
            default:
                return false
            }
        }
    }
    
    /// Account subtype enumeration
    enum AccountSubtype: Codable, CaseIterable, Equatable {
        case checking
        case savings
        case hsa
        case cd
        case moneyMarket
        case paypal
        case prepaid
        case cashManagement
        case ebt
        case creditCard
        case payoff
        case student
        case mortgage
        case auto
        case commercial
        case construction
        case consumer
        case homeEquity
        case lineOfCredit
        case loan
        case overdraft
        case business
        case personal
        case unknown(String)
        
        static var allCases: [AccountSubtype] {
            return [.checking, .savings, .hsa, .cd, .moneyMarket, .paypal, .prepaid, .cashManagement, .ebt, .creditCard, .payoff, .student, .mortgage, .auto, .commercial, .construction, .consumer, .homeEquity, .lineOfCredit, .loan, .overdraft, .business, .personal]
        }
        
        init(from decoder: Decoder) throws {
            let container = try decoder.singleValueContainer()
            let rawValue = try container.decode(String.self)
            
            switch rawValue {
            case "checking": self = .checking
            case "savings": self = .savings
            case "hsa": self = .hsa
            case "cd": self = .cd
            case "money market": self = .moneyMarket
            case "paypal": self = .paypal
            case "prepaid": self = .prepaid
            case "cash management": self = .cashManagement
            case "ebt": self = .ebt
            case "credit card": self = .creditCard
            case "payoff": self = .payoff
            case "student": self = .student
            case "mortgage": self = .mortgage
            case "auto": self = .auto
            case "commercial": self = .commercial
            case "construction": self = .construction
            case "consumer": self = .consumer
            case "home equity": self = .homeEquity
            case "line of credit": self = .lineOfCredit
            case "loan": self = .loan
            case "overdraft": self = .overdraft
            case "business": self = .business
            case "personal": self = .personal
            default: self = .unknown(rawValue)
            }
        }
        
        func encode(to encoder: Encoder) throws {
            var container = encoder.singleValueContainer()
            switch self {
            case .checking: try container.encode("checking")
            case .savings: try container.encode("savings")
            case .hsa: try container.encode("hsa")
            case .cd: try container.encode("cd")
            case .moneyMarket: try container.encode("money market")
            case .paypal: try container.encode("paypal")
            case .prepaid: try container.encode("prepaid")
            case .cashManagement: try container.encode("cash management")
            case .ebt: try container.encode("ebt")
            case .creditCard: try container.encode("credit card")
            case .payoff: try container.encode("payoff")
            case .student: try container.encode("student")
            case .mortgage: try container.encode("mortgage")
            case .auto: try container.encode("auto")
            case .commercial: try container.encode("commercial")
            case .construction: try container.encode("construction")
            case .consumer: try container.encode("consumer")
            case .homeEquity: try container.encode("home equity")
            case .lineOfCredit: try container.encode("line of credit")
            case .loan: try container.encode("loan")
            case .overdraft: try container.encode("overdraft")
            case .business: try container.encode("business")
            case .personal: try container.encode("personal")
            case .unknown(let value): try container.encode(value)
            }
        }
        
        static func == (lhs: AccountSubtype, rhs: AccountSubtype) -> Bool {
            switch (lhs, rhs) {
            case (.checking, .checking), (.savings, .savings), (.hsa, .hsa), (.cd, .cd), (.moneyMarket, .moneyMarket),
                 (.paypal, .paypal), (.prepaid, .prepaid), (.cashManagement, .cashManagement), (.ebt, .ebt),
                 (.creditCard, .creditCard), (.payoff, .payoff), (.student, .student), (.mortgage, .mortgage),
                 (.auto, .auto), (.commercial, .commercial), (.construction, .construction), (.consumer, .consumer),
                 (.homeEquity, .homeEquity), (.lineOfCredit, .lineOfCredit), (.loan, .loan), (.overdraft, .overdraft),
                 (.business, .business), (.personal, .personal):
                return true
            case (.unknown(let lhsValue), .unknown(let rhsValue)):
                return lhsValue == rhsValue
            default:
                return false
            }
        }
    }
}

// MARK: - Account Balance Model

/// Represents account balance information
struct AccountBalance: Codable, Equatable {
    let available: Double?
    let current: Double
    let limit: Double?
    let isoCurrencyCode: String?
    let unofficialCurrencyCode: String?
    
    enum CodingKeys: String, CodingKey {
        case available
        case current
        case limit
        case isoCurrencyCode = "iso_currency_code"
        case unofficialCurrencyCode = "unofficial_currency_code"
    }
}

// MARK: - Error Handling

/// Comprehensive error handling for Plaid API operations
enum PlaidError: Error, LocalizedError, Equatable {
    // Configuration Errors
    case missingCredentials
    case invalidConfiguration
    case missingEnvironmentVariable(String)
    
    // Network Errors
    case networkError(String)
    case invalidURL
    case noInternetConnection
    case requestTimeout
    
    // API Errors
    case apiError(code: String, message: String)
    case invalidResponse
    case decodingError(String)
    case encodingError(String)
    
    // Authentication Errors
    case invalidCredentials
    case expiredToken
    case insufficientPermissions
    
    // General Errors
    case unknown(String)
    
    var errorDescription: String? {
        switch self {
        // Configuration Errors
        case .missingCredentials:
            return "Plaid API credentials are missing or invalid"
        case .invalidConfiguration:
            return "Plaid configuration is invalid"
        case .missingEnvironmentVariable(let variable):
            return "Missing required environment variable: \(variable)"
            
        // Network Errors
        case .networkError(let message):
            return "Network error: \(message)"
        case .invalidURL:
            return "Invalid URL for Plaid API request"
        case .noInternetConnection:
            return "No internet connection available"
        case .requestTimeout:
            return "Request timed out"
            
        // API Errors
        case .apiError(let code, let message):
            return "Plaid API error [\(code)]: \(message)"
        case .invalidResponse:
            return "Invalid response from Plaid API"
        case .decodingError(let message):
            return "Failed to decode response: \(message)"
        case .encodingError(let message):
            return "Failed to encode request: \(message)"
            
        // Authentication Errors
        case .invalidCredentials:
            return "Invalid Plaid API credentials"
        case .expiredToken:
            return "Plaid access token has expired"
        case .insufficientPermissions:
            return "Insufficient permissions for this operation"
            
        // General Errors
        case .unknown(let message):
            return "Unknown error: \(message)"
        }
    }
    
    var failureReason: String? {
        switch self {
        case .missingCredentials, .invalidConfiguration:
            return "Check your Plaid API configuration in Info.plist"
        case .networkError, .noInternetConnection, .requestTimeout:
            return "Check your internet connection and try again"
        case .apiError:
            return "The Plaid API returned an error"
        case .invalidCredentials, .expiredToken:
            return "Authentication with Plaid API failed"
        default:
            return "An unexpected error occurred"
        }
    }
}

// MARK: - API Response Wrapper

/// Generic wrapper for consistent Plaid API response handling
struct PlaidAPIResponse<T: Codable>: Codable {
    let data: T?
    let error: PlaidAPIError?
    let requestId: String?
    
    enum CodingKeys: String, CodingKey {
        case data
        case error
        case requestId = "request_id"
    }
    
    /// Indicates if the response was successful
    var isSuccess: Bool {
        return error == nil && data != nil
    }
}

/// Plaid API error structure
struct PlaidAPIError: Codable, Equatable {
    let errorType: String
    let errorCode: String
    let errorMessage: String
    let displayMessage: String?
    
    enum CodingKeys: String, CodingKey {
        case errorType = "error_type"
        case errorCode = "error_code"
        case errorMessage = "error_message"
        case displayMessage = "display_message"
    }
}

// MARK: - Request/Response Models

/// Base request structure for Plaid API calls
struct PlaidBaseRequest: Codable {
    let clientId: String
    let secret: String
    
    enum CodingKeys: String, CodingKey {
        case clientId = "client_id"
        case secret
    }
}

/// Response structure for transactions endpoint
struct TransactionsResponse: Codable {
    let accounts: [PlaidAccount]
    let transactions: [PlaidTransaction]
    let totalTransactions: Int
    let requestId: String
    
    enum CodingKeys: String, CodingKey {
        case accounts
        case transactions
        case totalTransactions = "total_transactions"
        case requestId = "request_id"
    }
}

/// Response structure for accounts endpoint
struct AccountsResponse: Codable {
    let accounts: [PlaidAccount]
    let requestId: String
    
    enum CodingKeys: String, CodingKey {
        case accounts
        case requestId = "request_id"
    }
}

// MARK: - Sandbox Public Token Models

/// Request structure for creating sandbox public token
struct SandboxPublicTokenCreateRequest: Codable {
    let clientId: String
    let secret: String
    let institutionId: String
    let initialProducts: [String]
    let options: SandboxPublicTokenOptions?
    
    enum CodingKeys: String, CodingKey {
        case clientId = "client_id"
        case secret
        case institutionId = "institution_id"
        case initialProducts = "initial_products"
        case options
    }
}

/// Options for sandbox public token creation
struct SandboxPublicTokenOptions: Codable {
    let webhook: String?
    let overrideUsername: String?
    let overridePassword: String?
    
    enum CodingKeys: String, CodingKey {
        case webhook
        case overrideUsername = "override_username"
        case overridePassword = "override_password"
    }
    
    /// Creates options for dynamic transactions testing
    static func dynamicTransactions() -> SandboxPublicTokenOptions {
        return SandboxPublicTokenOptions(
            webhook: nil,
            overrideUsername: "user_transactions_dynamic",
            overridePassword: "anything-nonblank"
        )
    }
}

/// Response structure for sandbox public token creation
struct SandboxPublicTokenCreateResponse: Codable {
    let publicToken: String
    let requestId: String
    
    enum CodingKeys: String, CodingKey {
        case publicToken = "public_token"
        case requestId = "request_id"
    }
}

// MARK: - Item Public Token Exchange Models

/// Request structure for exchanging public token for access token
struct ItemPublicTokenExchangeRequest: Codable {
    let clientId: String
    let secret: String
    let publicToken: String
    
    enum CodingKeys: String, CodingKey {
        case clientId = "client_id"
        case secret
        case publicToken = "public_token"
    }
}

/// Response structure for public token exchange
struct ItemPublicTokenExchangeResponse: Codable {
    let accessToken: String
    let itemId: String
    let requestId: String
    
    enum CodingKeys: String, CodingKey {
        case accessToken = "access_token"
        case itemId = "item_id"
        case requestId = "request_id"
    }
}

// MARK: - Transactions Get Models

/// Options for transactions get request
struct TransactionsGetOptions: Codable {
    let accountIds: [String]?
    let count: Int?
    let offset: Int?
    
    enum CodingKeys: String, CodingKey {
        case accountIds = "account_ids"
        case count
        case offset
    }
}

/// Request structure for fetching transactions
struct TransactionsGetRequest: Codable {
    let clientId: String
    let secret: String
    let accessToken: String
    let startDate: String
    let endDate: String
    let options: TransactionsGetOptions?
    
    enum CodingKeys: String, CodingKey {
        case clientId = "client_id"
        case secret
        case accessToken = "access_token"
        case startDate = "start_date"
        case endDate = "end_date"
        case options
    }
}

// MARK: - Accounts Get Models

/// Request structure for fetching accounts
struct AccountsGetRequest: Codable {
    let clientId: String
    let secret: String
    let accessToken: String
    
    enum CodingKeys: String, CodingKey {
        case clientId = "client_id"
        case secret
        case accessToken = "access_token"
    }
}

// MARK: - Transactions Sync Models

/// Request structure for syncing transactions
struct TransactionsSyncRequest: Codable {
    let clientId: String
    let secret: String
    let accessToken: String
    let cursor: String?
    let count: Int?
    
    enum CodingKeys: String, CodingKey {
        case clientId = "client_id"
        case secret
        case accessToken = "access_token"
        case cursor
        case count
    }
}

/// Response structure for transactions sync
struct TransactionsSyncResponse: Codable {
    let added: [PlaidTransaction]
    let modified: [PlaidTransaction]
    let removed: [RemovedTransaction]
    let nextCursor: String
    let hasMore: Bool
    let requestId: String
    
    enum CodingKeys: String, CodingKey {
        case added
        case modified
        case removed
        case nextCursor = "next_cursor"
        case hasMore = "has_more"
        case requestId = "request_id"
    }
}

/// Structure for removed transactions
struct RemovedTransaction: Codable {
    let transactionId: String
    
    enum CodingKeys: String, CodingKey {
        case transactionId = "transaction_id"
    }
}

// MARK: - Sandbox Transaction Creation Models

/// Request structure for creating sandbox transactions
struct SandboxTransactionsCreateRequest: Codable {
    let clientId: String
    let secret: String
    let accessToken: String
    let transactions: [SandboxTransactionCreate]
    
    enum CodingKeys: String, CodingKey {
        case clientId = "client_id"
        case secret
        case accessToken = "access_token"
        case transactions
    }
}

/// Structure for creating individual sandbox transactions
struct SandboxTransactionCreate: Codable {
    let amount: Double
    let datePosted: String
    let dateTransacted: String
    let description: String
    
    enum CodingKeys: String, CodingKey {
        case amount
        case datePosted = "date_posted"
        case dateTransacted = "date_transacted"
        case description
    }
}

/// Response structure for sandbox transaction creation
struct SandboxTransactionsCreateResponse: Codable {
    let requestId: String
    
    enum CodingKeys: String, CodingKey {
        case requestId = "request_id"
    }
}

// MARK: - Institution Constants

/// Sandbox institution IDs for testing
struct SandboxInstitutions {
    static let firstPlatypus = "ins_109508"
    static let firstGila = "ins_109509"
    static let tartan = "ins_109510"
    static let houndstooth = "ins_109511"
    static let tattersall = "ins_109512"
    
    /// Default institution for sandbox testing
    static let `default` = firstPlatypus
}

/// Plaid product types
struct PlaidProducts {
    static let transactions = "transactions"
    static let accounts = "accounts"
    static let identity = "identity"
    static let assets = "assets"
    static let investments = "investments"
    static let liabilities = "liabilities"
    static let paymentInitiation = "payment_initiation"
    static let auth = "auth"
    
    /// Default products for sandbox testing
    static let defaultSandbox = [transactions]
}
