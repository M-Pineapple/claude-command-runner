import Foundation
import ArgumentParser
import MCP
import Logging
import ServiceLifecycle

// Command execution result structure
struct CommandExecutionResult: Codable {
    let commandId: String
    let command: String
    let output: String
    let error: String
    let exitCode: Int32
    let timestamp: Date
}

// Actor for thread-safe command results storage
actor CommandResultsStore {
    private var results: [String: CommandExecutionResult] = [:]
    
    func store(_ result: CommandExecutionResult) {
        results[result.commandId] = result
        results["last"] = result
    }
    
    func retrieve(_ commandId: String) -> CommandExecutionResult? {
        return results[commandId]
    }
}

// Global results store
let commandResultsStore = CommandResultsStore()

@main
struct ClaudeCommandRunner: AsyncParsableCommand {
    static let configuration = CommandConfiguration(
        commandName: "claude-command-runner",
        abstract: "MCP server bridging Claude Desktop and Warp Terminal",
        discussion: """
            Claude Command Runner acts as a bridge between Claude Desktop and Warp Terminal,
            enabling Claude to suggest terminal commands that can be executed seamlessly 
            within Warp's Agent Mode.
            
            Version 2.0: Now with two-way communication support!
            """
    )
    
    @Option(name: [.customLong("port"), .customShort("p")], help: "Port for the command receiver (default: 9876)")
    var port: Int = 9876
    
    @Option(name: [.customLong("log-level"), .customShort("l")], help: "Log level: debug, info, warning, error")
    var logLevel: String = "info"
    
    @Flag(name: .long, help: "Enable verbose logging")
    var verbose: Bool = false
    
    @Flag(name: .long, help: "Initialize configuration with example")
    var initConfig: Bool = false
    
    @Flag(name: .long, help: "Validate configuration")
    var validateConfig: Bool = false
    
    mutating func run() async throws {
        // Configure logging
        let logLevelStr = logLevel
        LoggingSystem.bootstrap { label in
            var handler = StreamLogHandler.standardError(label: label)
            handler.logLevel = Self.parseLogLevel(logLevelStr)
            return handler
        }
        
        let logger = Logger(label: "com.claude.command-runner")
        
        // Handle configuration operations
        if initConfig {
            try ConfigurationManager.initializeWithExample(logger: logger)
            print("Configuration initialized at \(ConfigurationManager.configDirectoryPath)")
            return
        }
        
        // Load configuration
        let configManager = ConfigurationManager(logger: logger)
        let config = configManager.current
        
        if validateConfig {
            let errors = configManager.validate()
            if errors.isEmpty {
                print("✅ Configuration is valid")
            } else {
                print("❌ Configuration errors:")
                for error in errors {
                    print("  - \(error)")
                }
            }
            return
        }
        
        // Override with command line arguments if provided
        let actualPort = port != 9876 ? port : config.port
        let actualLogLevel = logLevel != "info" ? logLevel : config.logging.level
        
        if verbose {
            logger.info("Starting Claude Command Runner MCP Server v2.0...")
            logger.info("Port: \(actualPort)")
            logger.info("Two-way communication: ENABLED")
            logger.info("Configuration loaded from: \(ConfigurationManager.configDirectoryPath)")
        }
        
        // Create the MCP server
        let server = Server(
            name: "Claude Command Runner",
            version: "2.0.0",
            capabilities: .init(
                tools: .init(listChanged: false)
            )
        )
        
        // Add tool handlers
        await server.withMethodHandler(ListTools.self) { _ in
            logger.debug("Listing available tools")
            return ListTools.Result(tools: [
                Tool(
                    name: "suggest_command",
                    description: "Suggests a terminal command based on the user's request",
                    inputSchema: .object([
                        "type": .string("object"),
                        "properties": .object([
                            "query": .object([
                                "type": .string("string"),
                                "description": .string("The user's request or task description")
                            ])
                        ]),
                        "required": .array([.string("query")])
                    ])
                ),
                Tool(
                    name: "execute_command",
                    description: "Executes a terminal command and captures its output",
                    inputSchema: .object([
                        "type": .string("object"),
                        "properties": .object([
                            "command": .object([
                                "type": .string("string"),
                                "description": .string("The command to execute")
                            ]),
                            "working_directory": .object([
                                "type": .string("string"),
                                "description": .string("Optional working directory for command execution")
                            ])
                        ]),
                        "required": .array([.string("command")])
                    ])
                ),
                Tool(
                    name: "execute_with_auto_retrieve",
                    description: "Executes a command and automatically waits for and returns its output",
                    inputSchema: .object([
                        "type": .string("object"),
                        "properties": .object([
                            "command": .object([
                                "type": .string("string"),
                                "description": .string("The command to execute")
                            ]),
                            "working_directory": .object([
                                "type": .string("string"),
                                "description": .string("Optional working directory for command execution")
                            ])
                        ]),
                        "required": .array([.string("command")])
                    ])
                ),
                Tool(
                    name: "preview_command",
                    description: "Preview a command without executing it",
                    inputSchema: .object([
                        "type": .string("object"),
                        "properties": .object([
                            "command": .object([
                                "type": .string("string"),
                                "description": .string("The command to preview")
                            ])
                        ]),
                        "required": .array([.string("command")])
                    ])
                ),
                Tool(
                    name: "get_command_output",
                    description: "Retrieve the output of a previously executed command",
                    inputSchema: .object([
                        "type": .string("object"),
                        "properties": .object([
                            "command_id": .object([
                                "type": .string("string"),
                                "description": .string("The command ID to retrieve output for (use 'last' for most recent)")
                            ])
                        ]),
                        "required": .array([])
                    ])
                )
            ])
        }
        
        await server.withMethodHandler(CallTool.self) { params in
            logger.info("Tool called: \(params.name)")
            
            switch params.name {
            case "suggest_command":
                return try await handleSuggestCommand(params: params, logger: logger)
            case "execute_command":
                return try await handleExecuteCommandV2(params: params, logger: logger, config: config)
            case "execute_with_auto_retrieve":
                return try await handleExecuteWithAutoRetrieve(params: params, logger: logger, config: config)
            case "preview_command":
                return try await handlePreviewCommand(params: params, logger: logger)
            case "get_command_output":
                return try await handleGetCommandOutput(params: params, logger: logger)
            default:
                return CallTool.Result(
                    content: [.text("Unknown tool: \(params.name)")],
                    isError: true
                )
            }
        }
        
        // Create transport and start server
        let transport = StdioTransport(logger: logger)
        let mcpService = MCPService(server: server, transport: transport)
        
        // Create command receiver service
        let commandReceiver = CommandReceiverService(port: actualPort, server: server, logger: logger)
        
        // Create service group
        let serviceGroup = ServiceGroup(
            services: [mcpService, commandReceiver],
            gracefulShutdownSignals: [.sigterm, .sigint],
            logger: logger
        )
        
        logger.info("MCP Server started successfully")
        logger.info("Command receiver listening on port \(actualPort)")
        
        // Run the service group
        try await serviceGroup.run()
    }
    
    private static func parseLogLevel(_ level: String) -> Logger.Level {
        switch level.lowercased() {
        case "debug": return .debug
        case "info": return .info
        case "warning": return .warning
        case "error": return .error
        default: return .info
        }
    }
}

// Import the enhanced suggest command handler
// The basic implementation is replaced by CommandSuggestionEngine.swift

func handlePreviewCommand(params: CallTool.Parameters, logger: Logger) async throws -> CallTool.Result {
    guard let arguments = params.arguments,
          let command = arguments["command"],
          case .string(let commandString) = command else {
        return CallTool.Result(
            content: [.text("Missing or invalid 'command' parameter")],
            isError: true
        )
    }
    
    logger.debug("Previewing command: \(commandString)")
    
    let preview = """
    Command Preview:
    ================
    \(commandString)
    
    This command will be executed in your current shell environment.
    Use 'execute_command' to run it.
    """
    
    return CallTool.Result(content: [.text(preview)], isError: false)
}

// New tool handler to retrieve command output
func handleGetCommandOutput(params: CallTool.Parameters, logger: Logger) async throws -> CallTool.Result {
    var commandId = "last" // Default to last command
    
    if let arguments = params.arguments,
       let id = arguments["command_id"],
       case .string(let idString) = id {
        commandId = idString
    }
    
    logger.info("Retrieving output for command ID: \(commandId)")
    
    // First try to get from memory
    var result = await commandResultsStore.retrieve(commandId)
    
    // If not in memory and not "last", try to read from disk
    if result == nil && commandId != "last" {
        logger.info("Not found in memory, checking disk...")
        let outputFile = "/tmp/claude_output_\(commandId).json"
        
        if FileManager.default.fileExists(atPath: outputFile) {
            do {
                let data = try Data(contentsOf: URL(fileURLWithPath: outputFile))
                let decoder = JSONDecoder()
                decoder.dateDecodingStrategy = .iso8601
                
                result = try decoder.decode(CommandExecutionResult.self, from: data)
                logger.info("Found and decoded output from disk")
                
                // Store it for future use
                if let result = result {
                    await commandResultsStore.store(result)
                }
            } catch {
                logger.error("Failed to read/decode output file: \(error)")
            }
        }
    }
    
    if let result = result {
        var output = """
        📊 Command Output Retrieved:
        ========================
        Command: \(result.command)
        Exit Code: \(result.exitCode)
        Timestamp: \(result.timestamp)
        
        Output:
        \(result.output)
        """
        
        if !result.error.isEmpty && result.error != "\n" {
            output += "\n\nError Output:\n\(result.error)"
        }
        
        return CallTool.Result(content: [.text(output)], isError: false)
    } else {
        // List available output files for debugging
        let tempDir = "/tmp"
        let files = try? FileManager.default.contentsOfDirectory(atPath: tempDir)
            .filter { $0.starts(with: "claude_output_") && $0.hasSuffix(".json") }
            .sorted()
            .suffix(5)
        
        var message = "No output found for command ID: \(commandId). The command may still be running or hasn't been executed yet."
        if let files = files, !files.isEmpty {
            message += "\n\nRecent output files available:\n" + files.joined(separator: "\n")
        }
        
        return CallTool.Result(content: [.text(message)], isError: false)
    }
}

// Helper functions for output capture
func createOutputCaptureScript(command: String, commandId: String) -> String {
    let outputFile = "/tmp/claude_output_\(commandId).json"
    
    return """
    #!/bin/bash
    
    # Command to execute
    COMMAND='\(command.replacingOccurrences(of: "'", with: "'\"'\"'"))'
    
    # Create a temporary file for stderr
    STDERR_FILE="/tmp/claude_stderr_\(commandId).tmp"
    
    # Execute command and capture output
    OUTPUT=$(eval "$COMMAND" 2>"$STDERR_FILE")
    EXIT_CODE=$?
    
    # Read stderr
    STDERR=$(<"$STDERR_FILE")
    rm -f "$STDERR_FILE"
    
    # Escape JSON strings
    escape_json() {
        python3 -c "import sys, json; print(json.dumps(sys.stdin.read()))" | sed 's/^"//;s/"$//'
    }
    
    # Create JSON result
    cat > "\(outputFile)" << EOF
    {
        "commandId": "\(commandId)",
        "command": "$(echo "$COMMAND" | escape_json)",
        "output": "$(echo "$OUTPUT" | escape_json)",
        "error": "$(echo "$STDERR" | escape_json)",
        "exitCode": $EXIT_CODE,
        "timestamp": "$(date -u +"%Y-%m-%dT%H:%M:%SZ")"
    }
    EOF
    
    # Signal completion by creating a marker file
    touch "\(outputFile).complete"
    
    # Also echo the output for immediate viewing in terminal
    echo "$OUTPUT"
    if [ -n "$STDERR" ]; then
        echo "$STDERR" >&2
    fi
    
    exit $EXIT_CODE
    """
}

/// Create AppleScript for different terminal types
private func createAppleScript(for terminal: TerminalConfig.TerminalType, command: String) -> String {
    switch terminal {
    case .warp, .warpPreview:
        return """
        tell application "\(terminal.rawValue)" to activate
        delay 0.5
        tell application "System Events"
            keystroke "\(command)"
        end tell
        """
        
    case .iterm2:
        return """
        tell application "iTerm"
            activate
            
            -- Get current terminal window or create new one
            if (count of windows) = 0 then
                create window with default profile
            end if
            
            tell current window
                tell current session
                    write text "\(command)"
                end tell
            end tell
        end tell
        """
        
    case .terminal:
        return """
        tell application "Terminal"
            activate
            
            -- Check if Terminal has windows
            if (count of windows) = 0 then
                do script "\(command)"
            else
                -- Use the frontmost window
                tell front window
                    do script "\(command)" in selected tab
                end tell
            end if
        end tell
        """
        
    case .alacritty:
        // Alacritty doesn't have AppleScript support, use keyboard events
        return """
        tell application "Alacritty" to activate
        delay 0.5
        tell application "System Events"
            keystroke "\(command)"
        end tell
        """
    }
}

// Function to wait for and retrieve command output
func waitForCommandOutput(commandId: String, timeout: TimeInterval = 30, logger: Logger) async throws -> CommandExecutionResult? {
    let outputFile = "/tmp/claude_output_\(commandId).json"
    let markerFile = "\(outputFile).complete"
    
    let startTime = Date()
    
    // Poll for completion
    while Date().timeIntervalSince(startTime) < timeout {
        if FileManager.default.fileExists(atPath: markerFile) {
            // Small delay to ensure file is fully written
            try await Task.sleep(nanoseconds: 100_000_000) // 0.1 seconds
            
            // Read the output file
            do {
                let data = try Data(contentsOf: URL(fileURLWithPath: outputFile))
                
                // Configure decoder with proper date format
                let decoder = JSONDecoder()
                decoder.dateDecodingStrategy = .iso8601
                
                let result = try decoder.decode(CommandExecutionResult.self, from: data)
                
                logger.info("Successfully decoded command output for \(commandId)")
                
                // Clean up files
                try? FileManager.default.removeItem(atPath: outputFile)
                try? FileManager.default.removeItem(atPath: markerFile)
                
                return result
            } catch {
                logger.error("Failed to decode command output: \(error)")
                // Try to read the raw content for debugging
                if let rawContent = try? String(contentsOf: URL(fileURLWithPath: outputFile)) {
                    logger.error("Raw JSON content: \(rawContent)")
                }
                // Don't remove files on error so we can debug
                return nil
            }
        }
        
        // Wait a bit before checking again
        try await Task.sleep(nanoseconds: 500_000_000) // 0.5 seconds
    }
    
    logger.info("Timeout reached waiting for command output")
    return nil
}
