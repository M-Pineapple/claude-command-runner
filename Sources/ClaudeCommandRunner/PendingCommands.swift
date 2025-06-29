import Foundation
import MCP
import Logging

/// Check for any commands that completed while Claude was "idle"
func handleCheckPendingCommands(params: CallTool.Parameters, logger: Logger) async throws -> CallTool.Result {
    let bridgeDir = "/tmp/claude_warp_bridge"
    let fileManager = FileManager.default
    
    var pendingCommands: [[String: Any]] = []
    
    // Check if bridge directory exists
    if fileManager.fileExists(atPath: bridgeDir) {
        do {
            let files = try fileManager.contentsOfDirectory(atPath: bridgeDir)
            
            for filename in files {
                if filename.hasPrefix("completed_") && filename.hasSuffix(".json") {
                    let filepath = "\(bridgeDir)/\(filename)"
                    
                    if let data = fileManager.contents(atPath: filepath),
                       let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any] {
                        pendingCommands.append(json)
                        
                        // Optional: Delete the notification after reading
                        try? fileManager.removeItem(atPath: filepath)
                    }
                }
            }
        } catch {
            logger.error("Error reading bridge directory: \(error)")
        }
    }
    
    if pendingCommands.isEmpty {
        return CallTool.Result(
            content: [.text("No pending command completions found.")],
            isError: false
        )
    }
    
    var response = "📬 Found \(pendingCommands.count) completed commands:\n\n"
    
    for (index, cmd) in pendingCommands.enumerated() {
        if let commandId = cmd["command_id"] as? String,
           let commandData = cmd["command_data"] as? [String: Any],
           let exitCode = commandData["exit_code"] as? Int {
            
            response += "Command #\(index + 1):\n"
            response += "  ID: \(commandId)\n"
            response += "  Exit Code: \(exitCode)\n"
            
            if let completedTime = commandData["completed_time"] as? String {
                response += "  Completed: \(completedTime)\n"
            }
            
            response += "\n"
        }
    }
    
    response += "Use 'get_command_output' with the command ID to retrieve the output."
    
    return CallTool.Result(
        content: [.text(response)],
        isError: false
    )
}
