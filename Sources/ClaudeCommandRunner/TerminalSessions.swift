import Foundation
import MCP
import Logging

// MARK: - v5.0.0: Multi-Terminal Orchestration

/// Represents a tracked terminal session (tab)
struct TerminalSession: Codable {
    let name: String
    let terminal: String // TerminalType rawValue
    let tabIndex: Int
    let createdAt: Date
    var lastCommandAt: Date
    var commandCount: Int
}

/// Actor for thread-safe terminal session management
actor SessionManager {
    private var sessions: [String: TerminalSession] = [:]
    private var nextTabIndex: [String: Int] = [:] // per-terminal tab counter

    func register(name: String, terminal: TerminalConfig.TerminalType) -> TerminalSession {
        let termKey = terminal.rawValue
        let index = nextTabIndex[termKey, default: 0]
        nextTabIndex[termKey] = index + 1

        let session = TerminalSession(
            name: name,
            terminal: termKey,
            tabIndex: index,
            createdAt: Date(),
            lastCommandAt: Date(),
            commandCount: 0
        )
        sessions[name] = session
        return session
    }

    func get(name: String) -> TerminalSession? {
        return sessions[name]
    }

    func updateLastCommand(name: String) {
        if var session = sessions[name] {
            session.lastCommandAt = Date()
            session.commandCount += 1
            sessions[name] = session
        }
    }

    func list() -> [TerminalSession] {
        return sessions.values.sorted { $0.createdAt < $1.createdAt }
    }

    func remove(name: String) -> TerminalSession? {
        return sessions.removeValue(forKey: name)
    }

    func exists(name: String) -> Bool {
        return sessions[name] != nil
    }
}

/// Global session manager
let sessionManager = SessionManager()

// MARK: - AppleScript Generators for Tab Management

/// Generate AppleScript to open a new tab in the specified terminal
private func newTabAppleScript(for terminal: TerminalConfig.TerminalType) -> String {
    switch terminal {
    case .warp, .warpPreview:
        return """
        tell application "\(terminal.rawValue)" to activate
        delay 0.5
        tell application "System Events"
            tell process "\(terminal.rawValue)"
                click menu item "New Tab" of menu "File" of menu bar 1
            end tell
        end tell
        delay 1.0
        """

    case .iterm2:
        return """
        tell application "iTerm"
            activate
            if (count of windows) = 0 then
                create window with default profile
            else
                tell current window
                    create tab with default profile
                end tell
            end if
        end tell
        delay 0.5
        """

    case .terminal:
        return """
        tell application "Terminal"
            activate
            if (count of windows) = 0 then
                do script ""
            else
                tell application "System Events"
                    tell process "Terminal"
                        keystroke "t" using command down
                    end tell
                end tell
            end if
        end tell
        delay 0.5
        """

    case .alacritty:
        // Alacritty doesn't support multiple tabs natively; open new window
        return """
        tell application "Alacritty" to activate
        delay 0.3
        tell application "System Events"
            tell process "Alacritty"
                keystroke "n" using command down
            end tell
        end tell
        delay 1.0
        """
    }
}

/// Generate AppleScript to send a command to a specific tab in iTerm2
private func iterm2SendToTab(tabIndex: Int, command: String) -> String {
    let escapedCommand = command.replacingOccurrences(of: "\\", with: "\\\\")
                                .replacingOccurrences(of: "\"", with: "\\\"")
    return """
    tell application "iTerm"
        activate
        tell current window
            set targetTab to tab \(tabIndex + 1)
            tell targetTab
                tell current session
                    write text "\(escapedCommand)"
                end tell
            end tell
        end tell
    end tell
    """
}

/// Generate AppleScript to send a command to a specific tab in Terminal.app
private func terminalSendToTab(tabIndex: Int, command: String) -> String {
    let escapedCommand = command.replacingOccurrences(of: "\\", with: "\\\\")
                                .replacingOccurrences(of: "\"", with: "\\\"")
    return """
    tell application "Terminal"
        activate
        if (count of windows) > 0 then
            tell front window
                set current tab to tab \(tabIndex + 1)
                do script "\(escapedCommand)" in selected tab
            end tell
        end if
    end tell
    """
}

/// Generate AppleScript to send command in a new tab (Warp/Alacritty — no native tab targeting)
private func keystrokeSendCommand(terminal: TerminalConfig.TerminalType, command: String) -> String {
    let escapedCommand = command.replacingOccurrences(of: "\\", with: "\\\\")
                                .replacingOccurrences(of: "\"", with: "\\\"")
    if terminal == .warp || terminal == .warpPreview {
        return """
        tell application "\(terminal.rawValue)" to activate
        delay 0.5
        tell application "System Events"
            tell process "\(terminal.rawValue)"
                click menu item "New Tab" of menu "File" of menu bar 1
            end tell
            delay 0.8
            keystroke "\(escapedCommand)"
            delay 0.2
            keystroke return
        end tell
        """
    } else {
        return """
        tell application "\(terminal.rawValue)" to activate
        delay 0.5
        tell application "System Events"
            keystroke "\(escapedCommand)"
            delay 0.2
            keystroke return
        end tell
        """
    }
}

/// Generate AppleScript to close the current tab
private func closeTabAppleScript(for terminal: TerminalConfig.TerminalType) -> String {
    switch terminal {
    case .warp, .warpPreview:
        return """
        tell application "\(terminal.rawValue)" to activate
        delay 0.3
        tell application "System Events"
            tell process "\(terminal.rawValue)"
                click menu item "Close Tab" of menu "File" of menu bar 1
            end tell
        end tell
        """

    case .alacritty:
        return """
        tell application "\(terminal.rawValue)" to activate
        delay 0.3
        tell application "System Events"
            tell process "\(terminal.rawValue)"
                keystroke "w" using command down
            end tell
        end tell
        """

    case .iterm2:
        return """
        tell application "iTerm"
            tell current window
                close current tab
            end tell
        end tell
        """

    case .terminal:
        return """
        tell application "Terminal"
            if (count of windows) > 0 then
                tell front window
                    close selected tab
                end tell
            end if
        end tell
        """
    }
}

// MARK: - AppleScript Execution Helper

@discardableResult
private func executeAppleScript(_ script: String, logger: Logger) -> (success: Bool, output: String) {
    let process = Process()
    process.executableURL = URL(fileURLWithPath: "/usr/bin/osascript")
    process.arguments = ["-e", script]

    let outputPipe = Pipe()
    let errorPipe = Pipe()
    process.standardOutput = outputPipe
    process.standardError = errorPipe

    do {
        try process.run()
        process.waitUntilExit()

        let outputData = outputPipe.fileHandleForReading.readDataToEndOfFile()
        let errorData = errorPipe.fileHandleForReading.readDataToEndOfFile()
        let output = String(data: outputData, encoding: .utf8) ?? ""
        let error = String(data: errorData, encoding: .utf8) ?? ""

        if process.terminationStatus == 0 {
            return (true, output.trimmingCharacters(in: .whitespacesAndNewlines))
        } else {
            logger.warning("AppleScript failed: \(error)")
            return (false, error.trimmingCharacters(in: .whitespacesAndNewlines))
        }
    } catch {
        logger.error("Failed to execute AppleScript: \(error)")
        return (false, error.localizedDescription)
    }
}

// MARK: - Tool Handlers

/// Handle open_terminal_tab tool
func handleOpenTerminalTab(params: CallTool.Parameters, logger: Logger) async -> CallTool.Result {
    guard let arguments = params.arguments,
          let nameValue = arguments["name"],
          case .string(let name) = nameValue else {
        return CallTool.Result(
            content: [.text("Missing required 'name' parameter — provide a name for this session")],
            isError: true
        )
    }

    // Check for duplicate session name
    if await sessionManager.exists(name: name) {
        return CallTool.Result(
            content: [.text("❌ Session '\(name)' already exists. Use 'send_to_session' to send commands, or 'close_session' to close it first.")],
            isError: true
        )
    }

    // Determine terminal type
    var terminal = TerminalConfig.getPreferredTerminal()
    if let termArg = arguments["terminal"], case .string(let termStr) = termArg {
        if let matched = TerminalConfig.TerminalType.allCases.first(where: {
            $0.rawValue.lowercased() == termStr.lowercased()
        }) {
            terminal = matched
        }
    }

    logger.info("Opening new terminal tab: \(name) in \(terminal.rawValue)")

    // Open new tab
    let script = newTabAppleScript(for: terminal)
    let result = executeAppleScript(script, logger: logger)

    guard result.success else {
        return CallTool.Result(
            content: [.text("❌ Failed to open new tab in \(terminal.rawValue): \(result.output)")],
            isError: true
        )
    }

    // Optionally send an initial command (e.g. cd to directory)
    if let dirArg = arguments["directory"], case .string(let dir) = dirArg {
        let cdScript = createAppleScript(for: terminal, command: "cd \"\(dir)\"")
        executeAppleScript(cdScript, logger: logger)
        // Small delay for cd to complete
        try? await Task.sleep(nanoseconds: 500_000_000)
    }

    // Register session
    let session = await sessionManager.register(name: name, terminal: terminal)

    var output = """
    ✅ New terminal tab opened: "\(name)"
    • Terminal: \(terminal.rawValue)
    • Tab index: \(session.tabIndex)
    """

    if let dirArg = arguments["directory"], case .string(let dir) = dirArg {
        output += "\n• Directory: \(dir)"
    }

    output += "\n\n💡 Use 'send_to_session' with name \"\(name)\" to send commands to this tab."

    return CallTool.Result(
        content: [.text(output)],
        isError: false
    )
}

/// Handle send_to_session tool
func handleSendToSession(params: CallTool.Parameters, logger: Logger) async -> CallTool.Result {
    guard let arguments = params.arguments,
          let nameValue = arguments["session_name"] ?? arguments["name"],
          case .string(let name) = nameValue,
          let commandValue = arguments["command"],
          case .string(let command) = commandValue else {
        return CallTool.Result(
            content: [.text("Missing required parameters: 'session_name' and 'command'")],
            isError: true
        )
    }

    guard let session = await sessionManager.get(name: name) else {
        let available = await sessionManager.list().map { $0.name }.joined(separator: ", ")
        return CallTool.Result(
            content: [.text("❌ Session '\(name)' not found.\(available.isEmpty ? " No active sessions." : " Available: \(available)")")],
            isError: true
        )
    }

    guard let terminal = TerminalConfig.TerminalType(rawValue: session.terminal) else {
        return CallTool.Result(
            content: [.text("❌ Unknown terminal type: \(session.terminal)")],
            isError: true
        )
    }

    logger.info("Sending command to session '\(name)': \(command)")

    // Build terminal-specific script to target the right tab
    let script: String
    switch terminal {
    case .iterm2:
        script = iterm2SendToTab(tabIndex: session.tabIndex, command: command)
    case .terminal:
        script = terminalSendToTab(tabIndex: session.tabIndex, command: command)
    case .warp, .warpPreview, .alacritty:
        // Warp and Alacritty don't support tab targeting via AppleScript
        // Best effort: activate terminal and type
        script = keystrokeSendCommand(terminal: terminal, command: command)
    }

    let result = executeAppleScript(script, logger: logger)

    guard result.success else {
        return CallTool.Result(
            content: [.text("❌ Failed to send command to session '\(name)': \(result.output)")],
            isError: true
        )
    }

    await sessionManager.updateLastCommand(name: name)

    let terminalNote: String
    switch terminal {
    case .warp, .warpPreview, .alacritty:
        terminalNote = "\n⚠️  \(terminal.rawValue) does not support direct tab targeting — command sent to active tab."
    default:
        terminalNote = ""
    }

    return CallTool.Result(
        content: [.text("""
        ✅ Command sent to session "\(name)":
        $ \(command.count > 80 ? String(command.prefix(80)) + "..." : command)\(terminalNote)
        """)],
        isError: false
    )
}

/// Handle list_sessions tool
func handleListSessions(params: CallTool.Parameters, logger: Logger) async -> CallTool.Result {
    let sessions = await sessionManager.list()

    if sessions.isEmpty {
        return CallTool.Result(
            content: [.text("📂 No active terminal sessions.\n\n💡 Use 'open_terminal_tab' to create one.")],
            isError: false
        )
    }

    let formatter = ISO8601DateFormatter()
    var output = "📂 Active Terminal Sessions (\(sessions.count)):\n"

    for session in sessions {
        output += "\n  \(session.name)"
        output += "\n    Terminal: \(session.terminal)"
        output += "\n    Tab index: \(session.tabIndex)"
        output += "\n    Commands sent: \(session.commandCount)"
        output += "\n    Created: \(formatter.string(from: session.createdAt))"
        output += "\n    Last command: \(formatter.string(from: session.lastCommandAt))"
    }

    return CallTool.Result(
        content: [.text(output)],
        isError: false
    )
}

/// Handle close_session tool
func handleCloseSession(params: CallTool.Parameters, logger: Logger) async -> CallTool.Result {
    guard let arguments = params.arguments,
          let nameValue = arguments["session_name"] ?? arguments["name"],
          case .string(let name) = nameValue else {
        return CallTool.Result(
            content: [.text("Missing required 'session_name' parameter")],
            isError: true
        )
    }

    guard let session = await sessionManager.remove(name: name) else {
        return CallTool.Result(
            content: [.text("❌ Session '\(name)' not found.")],
            isError: true
        )
    }

    // Optionally close the actual tab
    var closeTab = false
    if let closeArg = arguments["close_tab"], case .bool(let shouldClose) = closeArg {
        closeTab = shouldClose
    }

    if closeTab, let terminal = TerminalConfig.TerminalType(rawValue: session.terminal) {
        logger.info("Closing terminal tab for session: \(name)")
        let script = closeTabAppleScript(for: terminal)
        executeAppleScript(script, logger: logger)
    }

    return CallTool.Result(
        content: [.text("""
        ✅ Session "\(name)" removed.
        • Commands sent: \(session.commandCount)
        \(closeTab ? "• Terminal tab close signal sent." : "• Terminal tab left open (pass close_tab: true to close).")
        """)],
        isError: false
    )
}
