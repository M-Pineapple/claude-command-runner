import Foundation
import MCP
import Logging

// Execute command with automatic output retrieval - STABLE VERSION
func handleExecuteWithAutoRetrieveStable(params: CallTool.Parameters, logger: Logger, config: Configuration) async throws -> CallTool.Result {
    guard let arguments = params.arguments,
          let command = arguments["command"],
          case .string(let commandString) = command else {
        throw MCPError.invalidParams("Missing or invalid 'command' parameter")
    }
    
    // First, execute the command using the stable version without background monitoring
    let executeResult = try await handleExecuteCommandV2NoMonitoring(params: params, logger: logger, config: config)
    
    // Extract command ID from the result text
    var resultText = ""
    if case .text(let text) = executeResult.content.first {
        resultText = text
    }
    let commandId = extractCommandId(from: resultText)
    
    if let commandId = commandId {
        logger.info("Auto-retrieve mode: Starting limited monitoring for command \(commandId)")
        
        // STABILITY FIX: Limit auto-retrieve to just a few quick attempts
        // This prevents long-running loops that can crash the server
        let quickAttempts = 3 // Just 3 attempts over 6 seconds
        
        for attempt in 1...quickAttempts {
            // Wait briefly
            try await Task.sleep(nanoseconds: 2_000_000_000) // 2 seconds
            
            // Try to get output
            let outputParams = CallTool.Parameters(
                name: "get_command_output",
                arguments: ["command_id": .string(commandId)]
            )
            
            let outputResult = await handleGetCommandOutput(params: outputParams, logger: logger)
            
            // Check if we got actual output
            if case .text(let outputText) = outputResult.content.first,
               !outputText.contains("No output found for command ID") {
                
                // Success! Return combined result
                let combinedResult = """
                \(resultText)
                
                ⏱️ Output retrieved automatically after \(attempt * 2) seconds:
                
                \(outputText)
                """
                
                logger.info("Auto-retrieve successful after \(attempt) attempts")
                return CallTool.Result(content: [.text(combinedResult)], isError: false)
            }
        }
        
        // If we get here, auto-retrieve didn't get the output in time
        // Return the original result with a note
        let resultWithNote = """
        \(resultText)
        
        ℹ️ Auto-retrieve attempted but output not ready within 6 seconds.
        Use 'get_command_output' with the command ID above to retrieve manually.
        """
        
        return CallTool.Result(content: [.text(resultWithNote)], isError: false)
    }
    
    // No command ID found, just return the original result
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
