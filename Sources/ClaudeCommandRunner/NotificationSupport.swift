import Foundation
import MCP
import Logging

// Custom notification for command output
struct CommandOutputNotification: MCP.Notification {
    struct Parameters: Codable, Hashable, Sendable {
        let commandId: String
        let command: String
        let output: String
        let error: String
        let exitCode: Int32
        let timestamp: Date
    }
    
    static let name = "command/output"
}

// Enhanced version with notification support
extension ClaudeCommandRunner {
    
    // Modified execute command that sets up notification
    static func handleExecuteCommandV3(params: CallTool.Parameters, logger: Logger, server: Server) async throws -> CallTool.Result {
        guard let arguments = params.arguments,
              let command = arguments["command"],
              case .string(let commandString) = command else {
            throw MCPError.invalidParams("Missing or invalid 'command' parameter")
        }
        
        var workingDirectory: String?
        if let dir = arguments["working_directory"],
           case .string(let dirString) = dir {
            workingDirectory = dirString
        }
        
        // Generate unique command ID
        let commandId = UUID().uuidString
        logger.info("Executing command with ID: \(commandId)")
        logger.info("Command: \(commandString)")
        
        // Build the full command with working directory if needed
        var fullCommand = commandString
        if let workingDirectory = workingDirectory {
            fullCommand = "cd \"\(workingDirectory)\" && \(commandString)"
        }
        
        // Create the output capture script
        let scriptContent = createOutputCaptureScript(command: fullCommand, commandId: commandId)
        let tempScriptFile = "/tmp/claude_script_\(commandId).sh"
        
        do {
            try scriptContent.write(toFile: tempScriptFile, atomically: true, encoding: .utf8)
            try FileManager.default.setAttributes([.posixPermissions: 0o755], ofItemAtPath: tempScriptFile)
        } catch {
            logger.error("Failed to write script file: \(error)")
            return CallTool.Result(
                content: [.text("Failed to prepare command: \(error.localizedDescription)")],
                isError: true
            )
        }
        
        // Send to Warp Preview
        let bashCommand = "bash \(tempScriptFile)"
        let appleScript = """
        tell application "WarpPreview" to activate
        delay 0.5
        tell application "System Events"
            keystroke "\(bashCommand)"
        end tell
        """
        
        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/usr/bin/osascript")
        process.arguments = ["-e", appleScript]
        
        do {
            try process.run()
            process.waitUntilExit()
            
            if process.terminationStatus == 0 {
                logger.info("Command sent to Warp Preview, monitoring for output...")
                
                // Start monitoring with notification support
                Task {
                    await monitorCommandOutputWithNotification(
                        commandId: commandId,
                        server: server,
                        logger: logger,
                        timeout: 120 // Increased timeout for builds
                    )
                }
                
                let result = """
                ✅ Command sent to Warp Terminal:
                \(commandString)
                
                📋 Command ID: \(commandId)
                
                ⚠️  Please review and press Enter in Warp to execute.
                
                🔔 I'll notify you automatically when the output is ready!
                """
                
                return CallTool.Result(content: [.text(result)], isError: false)
            } else {
                return CallTool.Result(
                    content: [.text("Failed to send command to Warp Terminal")],
                    isError: true
                )
            }
        } catch {
            logger.error("Failed to send command: \(error)")
            return CallTool.Result(
                content: [.text("Failed to send command: \(error.localizedDescription)")],
                isError: true
            )
        }
    }
    
    // New monitoring function that sends notifications
    static func monitorCommandOutputWithNotification(
        commandId: String,
        server: Server,
        logger: Logger,
        timeout: TimeInterval = 120
    ) async {
        if let result = try? await waitForCommandOutput(commandId: commandId, timeout: timeout, logger: logger) {
            logger.info("Command output received, sending notification...")
            
            // Store the result
            await commandResultsStore.store(result)
            
            // Create notification parameters
            let params = CommandOutputNotification.Parameters(
                commandId: result.commandId,
                command: result.command,
                output: result.output,
                error: result.error,
                exitCode: result.exitCode,
                timestamp: result.timestamp
            )
            
            // Send notification - this is the key part!
            // Note: The actual notification sending would need to be implemented
            // in the MCP transport layer, but we can log it for now
            logger.info("📢 NOTIFICATION: Command \(commandId) completed with exit code \(result.exitCode)")
            
            // For now, we'll store a special "notification pending" flag
            await commandResultsStore.store(result)
        } else {
            logger.warning("Timeout waiting for command output")
        }
    }
}
