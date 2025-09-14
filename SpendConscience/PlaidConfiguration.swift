//
//  PlaidConfiguration.swift
//  SpendConscience
//
//  Configuration manager for Plaid API credentials and settings
//

import Foundation

/// Configuration manager for Plaid API credentials and environment settings
class PlaidConfiguration {
    
    // MARK: - Environment Detection
    
    /// Current environment (sandbox vs production)
    static var environment: PlaidEnvironment {
        #if DEBUG
        return .sandbox
        #else
        return .production
        #endif
    }
    
    // MARK: - API Credentials
    
    /// Plaid API secret from environment variables (renamed from apiKey for clarity)
    static var secret: String? {
        let key: String
        switch environment {
        case .sandbox:
            key = "PLAID_SANDBOX_API"
        case .production:
            key = "PLAID_SECRET"
        }
        
        guard let secret = Bundle.main.infoDictionary?[key] as? String,
              !secret.isEmpty else {
            print("❌ PlaidConfiguration: \(key) not found or empty in Info.plist")
            return nil
        }
        return secret
    }
    
    /// Legacy apiKey property for backward compatibility
    @available(*, deprecated, renamed: "secret")
    static var apiKey: String? {
        return secret
    }
    
    /// Plaid client ID from environment variables
    static var clientId: String? {
        guard let clientId = Bundle.main.infoDictionary?["PLAID_CLIENT"] as? String,
              !clientId.isEmpty else {
            print("❌ PlaidConfiguration: PLAID_CLIENT not found or empty in Info.plist")
            return nil
        }
        return clientId
    }
    
    // MARK: - API Base URLs
    
    /// Base URL for Plaid API based on current environment
    static var baseURL: String {
        switch environment {
        case .sandbox:
            return "https://sandbox.plaid.com"
        case .production:
            return "https://production.plaid.com"
        }
    }
    
    // MARK: - Validation Methods
    
    /// Validates that all required credentials are present and valid
    static func validateCredentials() -> Bool {
        guard let apiKey = apiKey, !apiKey.isEmpty else {
            print("❌ PlaidConfiguration: Invalid or missing API key")
            return false
        }
        
        guard let clientId = clientId, !clientId.isEmpty else {
            print("❌ PlaidConfiguration: Invalid or missing client ID")
            return false
        }
        
        print("✅ PlaidConfiguration: All credentials validated successfully")
        return true
    }
    
    /// Logs current configuration status
    static func logConfiguration() {
        print("🔧 PlaidConfiguration Status:")
        print("   Environment: \(environment.rawValue)")
        print("   Base URL: \(baseURL)")
        print("   API Key: \(apiKey != nil ? "✅ Present" : "❌ Missing")")
        print("   Client ID: \(clientId != nil ? "✅ Present" : "❌ Missing")")
        print("   Valid: \(validateCredentials() ? "✅" : "❌")")
    }
}

// MARK: - Supporting Types

/// Plaid environment enumeration
enum PlaidEnvironment: String, CaseIterable {
    case sandbox = "sandbox"
    case production = "production"
    
    var displayName: String {
        switch self {
        case .sandbox:
            return "Sandbox"
        case .production:
            return "Production"
        }
    }
}
