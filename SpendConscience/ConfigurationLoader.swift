//
//  ConfigurationLoader.swift
//  SpendConscience
//
//  Configuration loader for development API keys and settings
//

import Foundation

/// Configuration loader for development API keys and settings
struct ConfigurationLoader {
    
    // MARK: - Configuration Keys
    static let spendConscienceAPIURLKey = "SpendConscienceAPIURL"
    static let enableAIAssistantKey = "EnableAIAssistant"
    static let environmentKey = "Environment"
    static let debugModeKey = "DebugMode"
    
    // MARK: - Default Values
    private static let defaultAPIURL = "http://localhost:4001"
    
    // MARK: - Cache
    private static var cachedConfig: [String: Any]?
    private static let cacheQueue = DispatchQueue(label: "ConfigurationLoader.cache", attributes: .concurrent)
    
    /// Loads configuration from plist file with caching
    static func load() -> [String: Any] {
        return cacheQueue.sync {
            // Return cached configuration if available
            if let cached = cachedConfig {
                return cached
            }
            
            // Load configuration from file
            let configuration = loadFromFile()
            
            // Cache the result
            cachedConfig = configuration
            
            return configuration
        }
    }
    
    /// Reloads configuration from file, bypassing cache
    static func reload() -> [String: Any] {
        return cacheQueue.sync(flags: .barrier) {
            cachedConfig = nil
            return load()
        }
    }
    
    /// Loads configuration from plist file (internal implementation)
    private static func loadFromFile() -> [String: Any] {
        var configuration: [String: Any] = [:]
        
        // Try multiple locations for Config.Development.plist
        var possiblePaths: [String] = []
        
        // Use findConfigurationFile() which handles all possible locations
        if let configPath = findConfigurationFile() {
            possiblePaths.append(configPath)
        }
        
        for path in possiblePaths {
            if let plistData = NSDictionary(contentsOfFile: path) as? [String: Any] {
                configuration = plistData
                print("📄 ConfigurationLoader: Loaded configuration from \(path)")
                break
            }
        }
        
        if configuration.isEmpty {
            print("⚠️ ConfigurationLoader: No Config.Development.plist file found. Checked paths:")
            possiblePaths.forEach { print("   - \($0)") }
            
            // Additional debugging info
            print("   📍 Bundle path: \(Bundle.main.bundlePath)")
            print("    Bundle resources path: \(Bundle.main.resourcePath ?? "nil")")
            if let bundleResources = Bundle.main.resourcePath {
                let plistFiles = (try? FileManager.default.contentsOfDirectory(atPath: bundleResources))?.filter { $0.hasSuffix(".plist") } ?? []
                print("   📄 Available plist files in bundle: \(plistFiles)")
            }
            
            print("   💡 Run ./setup-development.sh to create the configuration file")
            print("   💡 Make sure to add Config.Development.plist to your Xcode project")
        }
        
        return configuration
    }
    
    /// Gets a string value from configuration
    static func getString(_ key: String) -> String? {
        let config = load()
        return config[key] as? String
    }
    
    /// Gets a boolean value from configuration
    static func getBool(_ key: String) -> Bool {
        let config = load()
        return config[key] as? Bool ?? false
    }
    
    // MARK: - Specific Configuration Methods
    
    /// Gets the API URL with proper fallback handling
    static func getAPIURL() -> String {
        let config = load()
        
        if let apiURL = config[spendConscienceAPIURLKey] as? String, !apiURL.isEmpty {
            // Validate URL format
            if URL(string: apiURL) != nil {
                print("🌐 ConfigurationLoader: Using configured API URL: \(apiURL)")
                return apiURL
            } else {
                print("⚠️ ConfigurationLoader: Invalid API URL format in configuration: \(apiURL)")
                print("   💡 Falling back to localhost for development")
            }
        } else {
            print("⚠️ ConfigurationLoader: SpendConscienceAPIURL not found in configuration")
            print("   💡 Falling back to localhost for development")
            print("   💡 Add SpendConscienceAPIURL to Config.Development.plist to use deployed backend")
        }
        
        return defaultAPIURL
    }
    
    /// Checks if AI Assistant is enabled
    static func isAIAssistantEnabled() -> Bool {
        return getBool(enableAIAssistantKey)
    }
    
    /// Validates the configuration and provides helpful error messages
    static func validateConfiguration() -> (isValid: Bool, errors: [String]) {
        let config = load()
        var errors: [String] = []
        
        // Check if configuration was loaded
        if config.isEmpty {
            errors.append("Configuration file not found or empty")
            return (false, errors)
        }
        
        // Check required keys
        if config[spendConscienceAPIURLKey] as? String == nil {
            errors.append("Missing required key: \(spendConscienceAPIURLKey)")
        } else if let apiURL = config[spendConscienceAPIURLKey] as? String {
            if apiURL.isEmpty {
                errors.append("SpendConscienceAPIURL is empty")
            } else if URL(string: apiURL) == nil {
                errors.append("SpendConscienceAPIURL has invalid format: \(apiURL)")
            }
        }
        
        // Check optional but recommended keys
        if config[enableAIAssistantKey] as? Bool == nil {
            errors.append("Missing recommended key: \(enableAIAssistantKey)")
        }
        
        if config[environmentKey] as? String == nil {
            errors.append("Missing recommended key: \(environmentKey)")
        }
        
        let isValid = errors.isEmpty
        
        if isValid {
            print("✅ ConfigurationLoader: Configuration validation passed")
        } else {
            print("❌ ConfigurationLoader: Configuration validation failed:")
            errors.forEach { print("   - \($0)") }
        }
        
        return (isValid, errors)
    }
    
    /// Finds the configuration file in various possible locations
    private static func findConfigurationFile() -> String? {
        // 1. Try bundle resource first (for production/Xcode builds)
        if let bundlePath = Bundle.main.path(forResource: "Config.Development", ofType: "plist") {
            return bundlePath
        }
        
        // 2. Try working directory (for development/script execution)
        let workingDirectory = FileManager.default.currentDirectoryPath
        let workingDirPaths = [
            "\(workingDirectory)/SpendConscience/Config.Development.plist",
            "\(workingDirectory)/Config.Development.plist"
        ]
        
        for path in workingDirPaths {
            if FileManager.default.fileExists(atPath: path) {
                return path
            }
        }
        
        // 3. Try walking up directory tree from bundle
        var currentPath = Bundle.main.bundlePath
        for _ in 0..<8 {
            let paths = [
                "\(currentPath)/SpendConscience/Config.Development.plist",
                "\(currentPath)/Config.Development.plist"
            ]
            
            for path in paths {
                if FileManager.default.fileExists(atPath: path) {
                    return path
                }
            }
            
            currentPath = (currentPath as NSString).deletingLastPathComponent
        }
        
        
        return nil
    }
}
