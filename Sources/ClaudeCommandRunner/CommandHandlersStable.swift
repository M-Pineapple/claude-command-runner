import Foundation
import MCP
import Logging

/// Version of execute command without background monitoring to prevent server crashes
func handleExecuteCommandV2NoMonitoring(params: CallTool.Parameters, logger: Logger, config: Configuration) async throws -> CallTool.Result {
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
            logger.info("Command sent to \(preferredTerminal.rawValue)")
            
            // NO BACKGROUND MONITORING - This prevents server crashes
            
            let result = """
            ✅ Command sent to \(preferredTerminal.rawValue):
            \(commandString)
            
            📋 Command ID: \(commandId)
            
            ⚠️  Please review and press Enter in \(preferredTerminal.rawValue) to execute.
            
            💡 After the command completes, use 'get_command_output' with ID: \(commandId)
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
