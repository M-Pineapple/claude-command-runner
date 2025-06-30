import Foundation
import MCP
import Logging

// Execute command with automatic output retrieval
func handleExecuteWithAutoRetrieve(params: CallTool.Parameters, logger: Logger, config: Configuration) async throws -> CallTool.Result {
    guard let arguments = params.arguments,
          let command = arguments["command"],
          case .string(let commandString) = command else {
        throw MCPError.invalidParams("Missing or invalid 'command' parameter")
    }
    
    // Working directory is not needed for auto-retrieve since it's handled in the execute call
    
    // First, execute the command using the stable version without background monitoring
    let executeResult = try await handleExecuteCommandV2NoMonitoring(params: params, logger: logger, config: config)
    
    // Extract command ID from the result text
    var resultText = ""
    if case .text(let text) = executeResult.content.first {
        resultText = text
    }
    let commandId = extractCommandId(from: resultText)
    
    if let commandId = commandId {
        logger.info("Auto-retrieve mode: Monitoring command \(commandId)")
        
        // Wait for output and return it immediately
        let maxAttempts = 60 // 60 attempts * 2 seconds = 2 minutes max
        for attempt in 1...maxAttempts {
            // Wait a bit
            try await Task.sleep(nanoseconds: 2_000_000_000) // 2 seconds
            
            // Try to get output
            let outputParams = CallTool.Parameters(
                name: "get_command_output",
                arguments: ["command_id": .string(commandId)]
            )
            
            let outputResult = await handleGetCommandOutput(params: outputParams, logger: logger)
            
            // Check if we got actual output (not the "not found" message)
            if case .text(let outputText) = outputResult.content.first,
               !outputText.contains("No output found for command ID") {
                
                // We got the output! Return combined result
                let combinedResult = """
                \(resultText)
                
                ⏱️ Output retrieved automatically after \(attempt * 2) seconds:
                
                \(outputText)
                """
                
                return CallTool.Result(content: [.text(combinedResult)], isError: false)
            }
            
            // For build commands, show progress
            if commandString.contains("build") && attempt % 5 == 0 {
                logger.info("Still waiting for build to complete... (\(attempt * 2)s elapsed)")
            }
        }
        
        // Timeout reached
        return CallTool.Result(content: [.text("\(resultText)\n\n⏱️ Auto-retrieve timeout after 2 minutes. Use 'get_command_output' manually.")], isError: false)
    }
    
    return executeResult
}

// Helper to extract command ID from result text
private func extractCommandId(from text: String) -> String? {
    // Look for "Command ID: XXXXXXXX-XXXX-XXXX-XXXX-XXXXXXXXXXXX"
    let pattern = "Command ID: ([A-F0-9\\-]+)"
    if let regex = try? NSRegularExpression(pattern: pattern),
       let match = regex.firstMatch(in: text, range: NSRange(text.startIndex..., in: text)) {
        if let range = Range(match.range(at: 1), in: text) {
            return String(text[range])
        }
    }
    return nil
}
