import Foundation
import MCP
import Logging

/// Enhanced execute command with terminal detection and output capture
func handleExecuteCommandV2(params: CallTool.Parameters, logger: Logger, config: Configuration) async throws -> CallTool.Result {
    guard let arguments = params.arguments,
          let command = arguments["command"],
          case .string(let commandString) = command else {
        return CallTool.Result(
            content: [.text("Missing or invalid 'command' parameter")],
            isError: true
        )
    }
    
    var workingDirectory: String?
    if let dir = arguments["working_directory"],
       case .string(let dirString) = dir {
        workingDirectory = dirString
    }
    
    // Generate unique command ID and record in database
    let commandId = UUID().uuidString
    logger.info("Executing command with ID: \(commandId)")
    logger.info("Command: \(commandString)")
    
    // Start database record
    let terminalType = config.getPreferredTerminal() ?? TerminalConfig.getPreferredTerminal()
    let projectId = DatabaseManager.shared.detectProjectFromDirectory(workingDirectory ?? FileManager.default.currentDirectoryPath)
    
    let commandRecord = CommandRecord(
        id: commandId,
        command: commandString,
        directory: workingDirectory,
        terminalType: terminalType.rawValue,
        projectId: projectId
    )
    
    _ = DatabaseManager.shared.saveCommand(commandRecord)
    
    // Record analytics event
    DatabaseManager.shared.recordAnalyticsEvent("command_executed", data: [
        "terminal": terminalType.rawValue,
        "has_project": projectId != nil
    ])
    
    // Security checks
    if config.isCommandBlocked(commandString) {
        logger.warning("Blocked command attempted: \(commandString)")
        return CallTool.Result(
            content: [.text("🚫 Command blocked by security policy. This command matches a blocked pattern.")],
            isError: true
        )
    }
    
    if commandString.count > config.security.maxCommandLength {
        return CallTool.Result(
            content: [.text("📏 Command too long. Maximum length: \(config.security.maxCommandLength) characters.")],
            isError: true
        )
    }
    
    // Detect preferred terminal
    let preferredTerminal = config.getPreferredTerminal() ?? TerminalConfig.getPreferredTerminal()
    logger.info("Using terminal: \(preferredTerminal.rawValue)")
    
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
        // Make script executable
        try FileManager.default.setAttributes([.posixPermissions: 0o755], ofItemAtPath: tempScriptFile)
    } catch {
        logger.error("Failed to write script file: \(error)")
        return CallTool.Result(
            content: [.text("Failed to prepare command: \(error.localizedDescription)")],
            isError: true
        )
    }
    
    // Send to terminal using AppleScript
    let bashCommand = "bash \(tempScriptFile)"
    let appleScript = createAppleScript(for: preferredTerminal, command: bashCommand)
    
    let process = Process()
    process.executableURL = URL(fileURLWithPath: "/usr/bin/osascript")
    process.arguments = ["-e", appleScript]
    
    let outputPipe = Pipe()
    let errorPipe = Pipe()
    process.standardOutput = outputPipe
    process.standardError = errorPipe
    
    do {
        try process.run()
        process.waitUntilExit()
        
        if process.terminationStatus == 0 {
            // Command sent successfully
            logger.info("Command sent to \(preferredTerminal.rawValue), monitoring for output...")
            
            // Start monitoring for output in background
            Task {
                if let result = try? await waitForCommandOutput(commandId: commandId, timeout: 60, logger: logger) {
                    logger.info("Command output received:")
                    logger.info("Exit code: \(result.exitCode)")
                    logger.info("Output: \(result.output)")
                    if !result.error.isEmpty {
                        logger.info("Error: \(result.error)")
                    }
                    
                    // Store the result for retrieval
                    await commandResultsStore.store(result)
                    
                    // Update database record
                    _ = DatabaseManager.shared.updateCommand(
                        commandId,
                        stdout: result.output,
                        stderr: result.error,
                        exitCode: Int(result.exitCode),
                        completedAt: Date()
                    )
                } else {
                    logger.warning("Timeout waiting for command output")
                }
            }
            
            let result = """
            ✅ Command sent to \(preferredTerminal.rawValue):
            \(commandString)
            
            📋 Command ID: \(commandId)
            
            ⚠️  Please review and press Enter in \(preferredTerminal.rawValue) to execute.
            
            💡 I'll automatically capture the output. Use 'get_command_output' or wait a moment for the results.
            """
            
            return CallTool.Result(content: [.text(result)], isError: false)
        } else {
            let errorData = errorPipe.fileHandleForReading.readDataToEndOfFile()
            let error = String(data: errorData, encoding: .utf8) ?? "Unknown error"
            logger.error("Failed to send command to \(preferredTerminal.rawValue): \(error)")
            
            // Provide helpful error message
            let installedTerminals = TerminalConfig.detectInstalledTerminals()
            var errorMessage = "Failed to send command to \(preferredTerminal.rawValue): \(error)"
            
            if !installedTerminals.contains(preferredTerminal) {
                errorMessage += "\n\n⚠️ \(preferredTerminal.rawValue) is not installed."
                if !installedTerminals.isEmpty {
                    errorMessage += "\nAvailable terminals: \(installedTerminals.map { $0.rawValue }.joined(separator: ", "))"
                }
            }
            
            return CallTool.Result(
                content: [.text(errorMessage)],
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

/// Execute with auto-retrieve combines execution and output retrieval
func handleExecuteWithAutoRetrieve(params: CallTool.Parameters, logger: Logger, config: Configuration) async throws -> CallTool.Result {
    // First execute the command
    let executeResult = try await handleExecuteCommandV2(params: params, logger: logger, config: config)
    
    // Extract command ID from the result
    if case let .text(resultText) = executeResult.content.first {
        // Parse command ID from the result text
        if let range = resultText.range(of: "Command ID: "),
           let endRange = resultText[range.upperBound...].range(of: "\n") {
            let commandId = String(resultText[range.upperBound..<endRange.lowerBound])
            
            logger.info("Auto-retrieving output for command ID: \(commandId)")
            
            // Wait for the command to complete (with longer timeout for builds)
            var attempts = 0
            let maxAttempts = 120 // 2 minutes max wait
            
            while attempts < maxAttempts {
                // Check if output is available
                if let result = await commandResultsStore.retrieve(commandId) {
                    var output = """
                    📊 Command Output (Auto-Retrieved):
                    ================================
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
                }
                
                // Check disk as fallback
                let outputFile = "/tmp/claude_output_\(commandId).json"
                if FileManager.default.fileExists(atPath: outputFile + ".complete") {
                    // Try to read from disk
                    if let data = try? Data(contentsOf: URL(fileURLWithPath: outputFile)),
                       let result = try? JSONDecoder().decode(CommandExecutionResult.self, from: data) {
                        await commandResultsStore.store(result)
                        
                        var output = """
                        📊 Command Output (Auto-Retrieved):
                        ================================
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
                    }
                }
                
                // Wait and retry
                try? await Task.sleep(nanoseconds: 1_000_000_000) // 1 second
                attempts += 1
            }
            
            // Timeout reached
            return CallTool.Result(
                content: [.text("⏱️ Command is still running after 2 minutes. Use 'get_command_output' with ID '\(commandId)' to check results later.")],
                isError: false
            )
        }
    }
    
    // Fallback if we couldn't parse the command ID
    return executeResult
}
