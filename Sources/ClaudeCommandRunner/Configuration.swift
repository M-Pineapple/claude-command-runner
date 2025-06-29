import Foundation
import Logging

/// Configuration structure for Claude Command Runner
public struct Configuration: Codable {
    public struct Terminal: Codable {
        public var preferred: String = "auto"
        public var fallbackOrder: [String] = ["Warp", "WarpPreview", "iTerm", "Terminal"]
        public var customPaths: [String: String] = [:]
    }
    
    public struct Security: Codable {
        public var allowedCommands: [String] = []
        public var blockedCommands: [String] = [
            "rm -rf /",
            ":(){ :|:& };:",
            "dd if=/dev/random of=/dev/sda",
            "mkfs.ext4 /dev/sda",
            "chmod -R 777 /",
            "chown -R"
        ]
        public var blockedPatterns: [String] = [
            ".*>/dev/sda.*",
            ".*format.*disk.*",
            ".*delete.*system.*"
        ]
        public var requireConfirmation: [String] = [
            "sudo",
            "rm -rf",
            "git push --force",
            "npm publish",
            "pod trunk push"
        ]
        public var maxCommandLength: Int = 1000
    }
    
    public struct Output: Codable {
        public var captureTimeout: Int = 60
        public var maxOutputSize: Int = 1048576 // 1MB
        public var timestampFormat: String = "yyyy-MM-dd HH:mm:ss"
        public var colorOutput: Bool = true
    }
    
    public struct History: Codable {
        public var enabled: Bool = true
        public var maxEntries: Int = 10000
        public var retentionDays: Int = 90
        public var databasePath: String?
    }
    
    public struct Logging: Codable {
        public var level: String = "info"
        public var filePath: String?
        public var maxFileSize: Int = 10485760 // 10MB
        public var rotateCount: Int = 5
    }
    
    public var terminal: Terminal = Terminal()
    public var security: Security = Security()
    public var output: Output = Output()
    public var history: History = History()
    public var logging: Logging = Logging()
    public var port: Int = 9876
    public var autoUpdate: Bool = true
    
    /// Default configuration
    public static var `default`: Configuration {
        return Configuration()
    }
}

/// Configuration manager for loading and saving config
public class ConfigurationManager {
    private static let configDirectory = FileManager.default.homeDirectoryForCurrentUser
        .appendingPathComponent(".claude-command-runner")
    private static let configFile = configDirectory.appendingPathComponent("config.json")
    
    private var configuration: Configuration
    private let logger: Logger?
    
    public init(logger: Logger? = nil) {
        self.logger = logger
        self.configuration = ConfigurationManager.load(logger: logger)
    }
    
    /// Get current configuration
    public var current: Configuration {
        return configuration
    }
    
    /// Load configuration from disk
    public static func load(logger: Logger? = nil) -> Configuration {
        // Ensure config directory exists
        try? FileManager.default.createDirectory(
            at: configDirectory,
            withIntermediateDirectories: true,
            attributes: nil
        )
        
        // Check if config file exists
        if FileManager.default.fileExists(atPath: configFile.path) {
            do {
                let data = try Data(contentsOf: configFile)
                let decoder = JSONDecoder()
                let config = try decoder.decode(Configuration.self, from: data)
                logger?.info("Configuration loaded from \(configFile.path)")
                return config
            } catch {
                logger?.error("Failed to load configuration: \(error)")
                logger?.info("Using default configuration")
            }
        } else {
            logger?.info("No configuration file found, using defaults")
            // Create default config file
            let defaultConfig = Configuration.default
            try? save(configuration: defaultConfig, logger: logger)
        }
        
        return Configuration.default
    }
    
    /// Save configuration to disk
    public static func save(configuration: Configuration, logger: Logger? = nil) throws {
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        let data = try encoder.encode(configuration)
        
        try data.write(to: configFile)
        logger?.info("Configuration saved to \(configFile.path)")
    }
    
    /// Update configuration
    public func update(_ block: (inout Configuration) -> Void) throws {
        block(&configuration)
        try ConfigurationManager.save(configuration: configuration, logger: logger)
    }
    
    /// Get configuration directory path
    public static var configDirectoryPath: String {
        return configDirectory.path
    }
    
    /// Initialize configuration with example file
    public static func initializeWithExample(logger: Logger? = nil) throws {
        let exampleConfig = Configuration.default
        
        // Add some example customizations
        var config = exampleConfig
        config.terminal.preferred = "Warp"
        config.security.blockedCommands.append("custom-dangerous-command")
        config.output.timestampFormat = "yyyy-MM-dd'T'HH:mm:ss.SSSZ"
        
        try save(configuration: config, logger: logger)
        
        // Also create an example file
        let exampleFile = configDirectory.appendingPathComponent("config.example.json")
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        let data = try encoder.encode(config)
        try data.write(to: exampleFile)
        
        logger?.info("Created example configuration at \(exampleFile.path)")
    }
    
    /// Validate configuration
    public func validate() -> [String] {
        var errors: [String] = []
        
        // Validate terminal
        if configuration.terminal.fallbackOrder.isEmpty {
            errors.append("Terminal fallback order cannot be empty")
        }
        
        // Validate security
        if configuration.security.maxCommandLength < 10 {
            errors.append("Maximum command length must be at least 10 characters")
        }
        
        // Validate output
        if configuration.output.captureTimeout < 1 {
            errors.append("Capture timeout must be at least 1 second")
        }
        
        if configuration.output.maxOutputSize < 1024 {
            errors.append("Maximum output size must be at least 1KB")
        }
        
        // Validate history
        if configuration.history.retentionDays < 0 {
            errors.append("Retention days cannot be negative")
        }
        
        // Validate port
        if configuration.port < 1024 || configuration.port > 65535 {
            errors.append("Port must be between 1024 and 65535")
        }
        
        return errors
    }
}

/// Extension for accessing configuration in command handlers
extension Configuration {
    /// Check if a command is blocked
    public func isCommandBlocked(_ command: String) -> Bool {
        // Check exact matches
        for blocked in security.blockedCommands {
            if command.contains(blocked) {
                return true
            }
        }
        
        // Check patterns
        for pattern in security.blockedPatterns {
            if let regex = try? NSRegularExpression(pattern: pattern, options: .caseInsensitive) {
                let range = NSRange(location: 0, length: command.utf16.count)
                if regex.firstMatch(in: command, options: [], range: range) != nil {
                    return true
                }
            }
        }
        
        return false
    }
    
    /// Check if a command requires confirmation
    public func requiresConfirmation(_ command: String) -> Bool {
        for pattern in security.requireConfirmation {
            if command.contains(pattern) {
                return true
            }
        }
        return false
    }
    
    /// Get preferred terminal type
    public func getPreferredTerminal() -> TerminalConfig.TerminalType? {
        if terminal.preferred == "auto" {
            return nil // Use auto-detection
        }
        
        return TerminalConfig.TerminalType.allCases.first { 
            $0.rawValue.lowercased() == terminal.preferred.lowercased() 
        }
    }
}
