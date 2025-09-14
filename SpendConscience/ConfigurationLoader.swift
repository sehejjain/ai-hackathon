//
//  ConfigurationLoader.swift
//  SpendConscience
//
//  Configuration loader for development API keys and settings
//

import Foundation

/// Configuration loader for development API keys and settings
struct ConfigurationLoader {
    
    /// Loads configuration from plist file
    static func load() -> [String: Any] {
        var configuration: [String: Any] = [:]
        
        // Try multiple locations for Config.Development.plist
        var possiblePaths: [String] = []
        
        // In the main bundle (if added to Xcode project)
        if let bundlePlistPath = Bundle.main.path(forResource: "Config.Development", ofType: "plist") {
            possiblePaths.append(bundlePlistPath)
        }
        
        // Alternative bundle resource names
        if let altBundlePlistPath = Bundle.main.path(forResource: "Config.Development", ofType: "plist") {
            possiblePaths.append(altBundlePlistPath)
        }
        
        // In the project directory (during development)
        if let projectPlistPath = findConfigurationFile() {
            possiblePaths.append(projectPlistPath)
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
            print("   � Bundle resources path: \(Bundle.main.resourcePath ?? "nil")")
            if let bundleResources = Bundle.main.resourcePath {
                let plistFiles = (try? FileManager.default.contentsOfDirectory(atPath: bundleResources))?.filter { $0.hasSuffix(".plist") } ?? []
                print("   📄 Available plist files in bundle: \(plistFiles)")
            }
            
            print("   �💡 Run ./setup-development.sh to create the configuration file")
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
        
        // 4. Try common development paths
        let commonPaths = [
            "\(NSHomeDirectory())/Projects/ai-hackathon/SpendConscience/Config.Development.plist",
            "\(NSHomeDirectory())/Projects/ai-hackathon/Config.Development.plist"
        ]
        
        for path in commonPaths {
            if FileManager.default.fileExists(atPath: path) {
                return path
            }
        }
        
        return nil
    }
}
