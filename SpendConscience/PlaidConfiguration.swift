//
//  PlaidConfiguration.swift
//  SpendConscience
//
//  Configuration manager for Plaid API credentials and settings
//

import Foundation

/// Configuration manager for Plaid API credentials and environment settings
class PlaidConfiguration {
    
    // MARK: - Environment Variables Cache
    
    /// Cached configuration from plist file
    private static let configVariables: [String: Any] = {
        return ConfigurationLoader.load()
    }()
    
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
    
    /// Plaid API secret from configuration (renamed from apiKey for clarity)
    /// Returns nil when using server-side backend integration
    static var secret: String? {
        let key: String
        switch environment {
        case .sandbox:
            key = "PlaidSandboxAPI"
        case .production:
            key = "PlaidSecret"
        }
        
        // 1. Try plist file first (for development)
        if let configSecret = configVariables[key] as? String,
           !configSecret.isEmpty,
           !configSecret.contains("YOUR_PLAID_") { // Skip placeholder values
            print("✅ PlaidConfiguration: Found \(key) in Config.Development.plist")
            return configSecret
        }
        
        // 2. Try environment variable (for testing/CI)
        let envKey = key == "PlaidSandboxAPI" ? "PLAID_SANDBOX_API" : "PLAID_SECRET"
        if let envSecret = ProcessInfo.processInfo.environment[envKey],
           !envSecret.isEmpty {
            print("✅ PlaidConfiguration: Found \(envKey) in environment variables")
            return envSecret
        }
        
        // 3. Fall back to Info.plist (from xcconfig)
        if let secret = Bundle.main.infoDictionary?[envKey] as? String,
           !secret.isEmpty {
            print("✅ PlaidConfiguration: Found \(envKey) in Info.plist")
            return secret
        }
        
        // Graceful handling when using server-side backend
        if ConfigurationLoader.getString(ConfigurationLoader.spendConscienceAPIURLKey) != nil {
            print("ℹ️ PlaidConfiguration: Using server-side Plaid integration - client-side keys not required")
        } else {
            print("❌ PlaidConfiguration: \(key) not found in plist, environment variables, or Info.plist")
            print("   💡 Run ./setup-development.sh to configure your environment")
        }
        return nil
    }
    
    /// Legacy apiKey property for backward compatibility
    @available(*, deprecated, renamed: "secret")
    static var apiKey: String? {
        return secret
    }
    
    /// Plaid client ID from configuration
    /// Returns nil when using server-side backend integration
    static var clientId: String? {
        // 1. Try plist file first (for development)
        if let configClientId = configVariables["PlaidClientID"] as? String,
           !configClientId.isEmpty,
           !configClientId.contains("YOUR_PLAID_") { // Skip placeholder values
            print("✅ PlaidConfiguration: Found PlaidClientID in Config.Development.plist")
            return configClientId
        }
        
        // 2. Try environment variable (for testing/CI)
        if let envClientId = ProcessInfo.processInfo.environment["PLAID_CLIENT"],
           !envClientId.isEmpty {
            print("✅ PlaidConfiguration: Found PLAID_CLIENT in environment variables")
            return envClientId
        }
        
        // 3. Fall back to Info.plist (from xcconfig)
        if let clientId = Bundle.main.infoDictionary?["PLAID_CLIENT"] as? String,
           !clientId.isEmpty {
            print("✅ PlaidConfiguration: Found PLAID_CLIENT in Info.plist")
            return clientId
        }
        
        // Graceful handling when using server-side backend
        if ConfigurationLoader.getString(ConfigurationLoader.spendConscienceAPIURLKey) != nil {
            print("ℹ️ PlaidConfiguration: Using server-side Plaid integration - client-side keys not required")
        } else {
            print("❌ PlaidConfiguration: PlaidClientID not found in plist, environment variables, or Info.plist")
            print("   💡 Run ./setup-development.sh to configure your environment")
        }
        return nil
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
    /// Returns true when using server-side backend integration
    static func validateCredentials() -> Bool {
        // If using server-side backend, client-side Plaid credentials are not required
        if ConfigurationLoader.getString(ConfigurationLoader.spendConscienceAPIURLKey) != nil {
            print("✅ PlaidConfiguration: Using server-side integration - validation passed")
            return true
        }
        
        // For direct Plaid integration, validate credentials
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
        
        if ConfigurationLoader.getString(ConfigurationLoader.spendConscienceAPIURLKey) != nil {
            print("   Integration Mode: Server-side (SpendConscience API)")
            print("   API Key: Not required for server-side integration")
            print("   Client ID: Not required for server-side integration")
        } else {
            print("   Integration Mode: Direct Plaid")
            print("   API Key: \(apiKey != nil ? "✅ Present" : "❌ Missing")")
            print("   Client ID: \(clientId != nil ? "✅ Present" : "❌ Missing")")
        }
        
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
