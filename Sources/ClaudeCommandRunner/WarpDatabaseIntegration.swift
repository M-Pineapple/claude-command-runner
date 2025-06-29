import Foundation
import SQLite3

/// WarpDatabaseIntegration provides direct access to Warp's command history
/// This eliminates the need for duplicate logging by reading directly from Warp's SQLite database
class WarpDatabaseIntegration {
    private let warpDbPath: String
    private var db: OpaquePointer?
    
    init(terminalType: TerminalConfig.TerminalType? = nil) {
        let terminal = terminalType ?? TerminalConfig.getPreferredTerminal()
        if let dbPath = TerminalConfig.getWarpDatabasePath(for: terminal) {
            self.warpDbPath = dbPath
        } else {
            // Fallback to Warp stable
            let homeDir = FileManager.default.homeDirectoryForCurrentUser.path
            self.warpDbPath = "\(homeDir)/Library/Application Support/dev.warp.Warp/warp.sqlite"
        }
    }
    
    /// Connect to Warp's SQLite database
    func connect() -> Bool {
        if sqlite3_open(warpDbPath, &db) == SQLITE_OK {
            return true
        } else {
            print("Unable to open Warp database")
            return false
        }
    }
    
    /// Disconnect from the database
    func disconnect() {
        sqlite3_close(db)
    }
    
    /// Get recent commands from Warp's database
    func getRecentCommands(limit: Int = 50) -> [[String: Any]] {
        guard connect() else { return [] }
        defer { disconnect() }
        
        var commands: [[String: Any]] = []
        let queryString = """
            SELECT 
                id,
                command,
                exit_code,
                datetime(start_ts) as start_time,
                datetime(completed_ts) as completed_time,
                pwd as working_directory,
                shell,
                username,
                hostname,
                session_id,
                git_branch
            FROM commands 
            WHERE start_ts IS NOT NULL
            ORDER BY start_ts DESC 
            LIMIT ?
        """
        
        var statement: OpaquePointer?
        
        if sqlite3_prepare_v2(db, queryString, -1, &statement, nil) == SQLITE_OK {
            sqlite3_bind_int(statement, 1, Int32(limit))
            
            while sqlite3_step(statement) == SQLITE_ROW {
                var command: [String: Any] = [:]
                
                command["id"] = Int(sqlite3_column_int(statement, 0))
                
                if let cmdText = sqlite3_column_text(statement, 1) {
                    command["command"] = String(cString: cmdText)
                }
                
                let exitCode = sqlite3_column_int(statement, 2)
                if exitCode != -1 {
                    command["exit_code"] = Int(exitCode)
                }
                
                if let startTime = sqlite3_column_text(statement, 3) {
                    command["start_time"] = String(cString: startTime)
                }
                
                if let completedTime = sqlite3_column_text(statement, 4) {
                    command["completed_time"] = String(cString: completedTime)
                }
                
                if let pwd = sqlite3_column_text(statement, 5) {
                    command["working_directory"] = String(cString: pwd)
                }
                
                commands.append(command)
            }
        }
        
        sqlite3_finalize(statement)
        return commands
    }
    
    /// Get commands specifically executed by Claude Command Runner
    func getClaudeCommands(limit: Int = 50) -> [[String: Any]] {
        guard connect() else { return [] }
        defer { disconnect() }
        
        var commands: [[String: Any]] = []
        let queryString = """
            SELECT 
                id,
                command,
                exit_code,
                datetime(start_ts) as start_time,
                datetime(completed_ts) as completed_time,
                pwd as working_directory
            FROM commands 
            WHERE command LIKE '%claude_script_%' 
               OR command LIKE '%/tmp/claude_%'
            ORDER BY start_ts DESC 
            LIMIT ?
        """
        
        var statement: OpaquePointer?
        
        if sqlite3_prepare_v2(db, queryString, -1, &statement, nil) == SQLITE_OK {
            sqlite3_bind_int(statement, 1, Int32(limit))
            
            while sqlite3_step(statement) == SQLITE_ROW {
                var command: [String: Any] = [:]
                
                command["id"] = Int(sqlite3_column_int(statement, 0))
                
                if let cmdText = sqlite3_column_text(statement, 1) {
                    let commandStr = String(cString: cmdText)
                    command["command"] = commandStr
                    
                    // Extract command ID from the script name
                    if commandStr.contains("claude_script_") {
                        let components = commandStr.components(separatedBy: "claude_script_")
                        if components.count > 1 {
                            let cmdId = components[1].replacingOccurrences(of: ".sh", with: "")
                            command["command_id"] = cmdId
                        }
                    }
                }
                
                let exitCode = sqlite3_column_int(statement, 2)
                if exitCode != -1 {
                    command["exit_code"] = Int(exitCode)
                }
                
                if let startTime = sqlite3_column_text(statement, 3) {
                    command["start_time"] = String(cString: startTime)
                }
                
                if let completedTime = sqlite3_column_text(statement, 4) {
                    command["completed_time"] = String(cString: completedTime)
                }
                
                if let pwd = sqlite3_column_text(statement, 5) {
                    command["working_directory"] = String(cString: pwd)
                }
                
                commands.append(command)
            }
        }
        
        sqlite3_finalize(statement)
        return commands
    }
    
    /// Get command by ID
    func getCommandById(_ commandId: String) -> [String: Any]? {
        guard connect() else { return nil }
        defer { disconnect() }
        
        let queryString = """
            SELECT 
                id,
                command,
                exit_code,
                datetime(start_ts) as start_time,
                datetime(completed_ts) as completed_time,
                pwd as working_directory
            FROM commands 
            WHERE command LIKE ?
            ORDER BY start_ts DESC 
            LIMIT 1
        """
        
        var statement: OpaquePointer?
        
        if sqlite3_prepare_v2(db, queryString, -1, &statement, nil) == SQLITE_OK {
            let searchPattern = "%\(commandId)%"
            sqlite3_bind_text(statement, 1, searchPattern, -1, nil)
            
            if sqlite3_step(statement) == SQLITE_ROW {
                var command: [String: Any] = [:]
                
                command["id"] = Int(sqlite3_column_int(statement, 0))
                
                if let cmdText = sqlite3_column_text(statement, 1) {
                    command["command"] = String(cString: cmdText)
                }
                
                let exitCode = sqlite3_column_int(statement, 2)
                if exitCode != -1 {
                    command["exit_code"] = Int(exitCode)
                }
                
                if let startTime = sqlite3_column_text(statement, 3) {
                    command["start_time"] = String(cString: startTime)
                }
                
                if let completedTime = sqlite3_column_text(statement, 4) {
                    command["completed_time"] = String(cString: completedTime)
                }
                
                if let pwd = sqlite3_column_text(statement, 5) {
                    command["working_directory"] = String(cString: pwd)
                }
                
                sqlite3_finalize(statement)
                return command
            }
        }
        
        sqlite3_finalize(statement)
        return nil
    }
    
    /// Display recent command history
    func displayRecentHistory(limit: Int = 20) {
        let commands = getRecentCommands(limit: limit)
        
        if commands.isEmpty {
            print("No commands found in Warp history")
            return
        }
        
        print("\n📜 Last \(limit) commands from Warp:")
        print(String(repeating: "=", count: 80))
        
        for cmd in commands {
            let timeStr = cmd["start_time"] as? String ?? "Unknown time"
            let exitCode = cmd["exit_code"] as? Int
            let exitCodeStr = exitCode != nil ? "\(exitCode!)" : "?"
            
            var commandStr = cmd["command"] as? String ?? ""
            if commandStr.count > 60 {
                commandStr = String(commandStr.prefix(57)) + "..."
            }
            
            let statusEmoji = exitCode == 0 ? "✅" : (exitCode != nil ? "❌" : "⏳")
            
            print("\(statusEmoji) [\(timeStr)] Exit: \(exitCodeStr)")
            print("   📂 \(cmd["working_directory"] as? String ?? "Unknown directory")")
            print("   $ \(commandStr)")
            print(String(repeating: "-", count: 80))
        }
    }
}
