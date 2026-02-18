import Foundation
import MCP
import Logging

// MARK: - v5.0.0: Output Intelligence — Structured Parsing

/// Handle execute_and_parse tool — execute command and return structured output
func handleExecuteAndParse(params: CallTool.Parameters, logger: Logger, config: Configuration) async throws -> CallTool.Result {
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

    // Security check
    if config.isCommandBlocked(commandString) {
        return CallTool.Result(
            content: [.text("🚫 Command blocked by security policy.")],
            isError: true
        )
    }

    logger.info("Execute and parse: \(commandString)")

    // Execute command directly (captures output in-process)
    var fullCommand = commandString
    if let dir = workingDirectory {
        fullCommand = "cd \"\(dir)\" && \(commandString)"
    }

    let process = Process()
    process.executableURL = URL(fileURLWithPath: "/bin/bash")
    process.arguments = ["-c", fullCommand]

    let outputPipe = Pipe()
    let errorPipe = Pipe()
    process.standardOutput = outputPipe
    process.standardError = errorPipe

    do {
        try process.run()
        process.waitUntilExit()

        let outputData = outputPipe.fileHandleForReading.readDataToEndOfFile()
        let errorData = errorPipe.fileHandleForReading.readDataToEndOfFile()
        let stdout = String(data: outputData, encoding: .utf8) ?? ""
        let stderr = String(data: errorData, encoding: .utf8) ?? ""
        let exitCode = process.terminationStatus

        // Detect command type and apply parser
        let parsed = applyParser(command: commandString, stdout: stdout, stderr: stderr, exitCode: exitCode, logger: logger)

        return CallTool.Result(
            content: [.text(parsed)],
            isError: exitCode != 0
        )
    } catch {
        logger.error("Execute and parse failed: \(error)")
        return CallTool.Result(
            content: [.text("❌ Execution failed: \(error.localizedDescription)")],
            isError: true
        )
    }
}

// MARK: - Parser Detection & Application

private func applyParser(command: String, stdout: String, stderr: String, exitCode: Int32, logger: Logger) -> String {
    let cmd = command.trimmingCharacters(in: .whitespaces)

    // Try JSON passthrough first
    if let jsonParsed = tryParseJSON(stdout) {
        return """
        📊 Parsed Output (JSON):
        Exit Code: \(exitCode)

        \(jsonParsed)
        """
    }

    // Git status
    if cmd.hasPrefix("git status") {
        return parseGitStatus(stdout: stdout, exitCode: exitCode)
    }

    // Git log
    if cmd.hasPrefix("git log") {
        return parseGitLog(stdout: stdout, exitCode: exitCode)
    }

    // Docker ps
    if cmd.hasPrefix("docker ps") {
        return parseDockerPs(stdout: stdout, exitCode: exitCode)
    }

    // Test runners
    if cmd.contains("pytest") || cmd.contains("python -m pytest") {
        return parseTestResults(stdout: stdout, stderr: stderr, exitCode: exitCode, runner: "pytest")
    }
    if cmd.contains("npm test") || cmd.contains("npx jest") || cmd.contains("jest") {
        return parseTestResults(stdout: stdout, stderr: stderr, exitCode: exitCode, runner: "jest/npm")
    }
    if cmd.hasPrefix("swift test") {
        return parseTestResults(stdout: stdout, stderr: stderr, exitCode: exitCode, runner: "swift test")
    }

    // ls -la
    if cmd.hasPrefix("ls -l") || cmd.hasPrefix("ls -al") || cmd.hasPrefix("ls -la") {
        return parseLsLong(stdout: stdout, exitCode: exitCode)
    }

    // Default: return raw with metadata
    return """
    📊 Command Output:
    Exit Code: \(exitCode)

    stdout:
    \(stdout.isEmpty ? "(empty)" : stdout)
    \(stderr.isEmpty ? "" : "\nstderr:\n\(stderr)")
    """
}

// MARK: - Individual Parsers

private func parseGitStatus(stdout: String, exitCode: Int32) -> String {
    var staged: [String] = []
    var unstaged: [String] = []
    var untracked: [String] = []
    var branch = "unknown"

    for line in stdout.components(separatedBy: "\n") {
        let trimmed = line.trimmingCharacters(in: .whitespaces)

        if trimmed.hasPrefix("On branch ") {
            branch = String(trimmed.dropFirst("On branch ".count))
        } else if trimmed.hasPrefix("##") {
            // Short format branch line
            let parts = trimmed.dropFirst(3).split(separator: ".")
            if let first = parts.first {
                branch = String(first)
            }
        }

        // Porcelain format parsing
        if line.count >= 3 {
            let index = line.index(line.startIndex, offsetBy: 0)
            let worktree = line.index(line.startIndex, offsetBy: 1)
            let file = String(line.dropFirst(3))

            if line[index] != " " && line[index] != "?" {
                staged.append("\(line[index]) \(file)")
            }
            if line[worktree] != " " && line[worktree] != "?" {
                unstaged.append("\(line[worktree]) \(file)")
            }
            if line[index] == "?" {
                untracked.append(file)
            }
        }
    }

    return """
    🔀 Git Status (parsed):
    Branch: \(branch)
    Staged: \(staged.isEmpty ? "none" : "\(staged.count) file(s)")
    \(staged.map { "  • \($0)" }.joined(separator: "\n"))
    Unstaged: \(unstaged.isEmpty ? "none" : "\(unstaged.count) file(s)")
    \(unstaged.map { "  • \($0)" }.joined(separator: "\n"))
    Untracked: \(untracked.isEmpty ? "none" : "\(untracked.count) file(s)")
    \(untracked.map { "  • \($0)" }.joined(separator: "\n"))
    """
}

private func parseGitLog(stdout: String, exitCode: Int32) -> String {
    var commits: [String] = []

    for line in stdout.components(separatedBy: "\n") where !line.isEmpty {
        let trimmed = line.trimmingCharacters(in: .whitespaces)
        if !trimmed.isEmpty {
            commits.append(trimmed)
        }
    }

    return """
    📜 Git Log (parsed):
    Commits: \(commits.count)

    \(commits.prefix(20).enumerated().map { "  \($0.offset + 1). \($0.element)" }.joined(separator: "\n"))
    \(commits.count > 20 ? "\n  ... and \(commits.count - 20) more" : "")
    """
}

private func parseDockerPs(stdout: String, exitCode: Int32) -> String {
    let lines = stdout.components(separatedBy: "\n").filter { !$0.isEmpty }
    guard lines.count > 1 else {
        return "🐳 Docker: No running containers"
    }

    var containers: [String] = []
    for line in lines.dropFirst() {
        containers.append("  • \(line.trimmingCharacters(in: .whitespaces))")
    }

    return """
    🐳 Docker Containers (parsed):
    Running: \(containers.count)

    \(containers.joined(separator: "\n"))
    """
}

private func parseTestResults(stdout: String, stderr: String, exitCode: Int32, runner: String) -> String {
    let combined = stdout + "\n" + stderr
    var passed = 0
    var failed = 0
    var skipped = 0
    var errors: [String] = []

    // pytest patterns
    if runner == "pytest" {
        // Look for summary line like "5 passed, 2 failed, 1 skipped"
        for line in combined.components(separatedBy: "\n") {
            if line.contains("passed") || line.contains("failed") || line.contains("error") {
                if let match = line.range(of: #"(\d+) passed"#, options: .regularExpression) {
                    passed = Int(line[match].split(separator: " ").first ?? "0") ?? 0
                }
                if let match = line.range(of: #"(\d+) failed"#, options: .regularExpression) {
                    failed = Int(line[match].split(separator: " ").first ?? "0") ?? 0
                }
                if let match = line.range(of: #"(\d+) skipped"#, options: .regularExpression) {
                    skipped = Int(line[match].split(separator: " ").first ?? "0") ?? 0
                }
            }
            if line.contains("FAILED") || line.contains("ERROR") {
                errors.append(line.trimmingCharacters(in: .whitespaces))
            }
        }
    }

    // Swift test patterns
    if runner == "swift test" {
        for line in combined.components(separatedBy: "\n") {
            if line.contains("Test Suite") && line.contains("passed") {
                // "Test Suite 'All tests' passed" pattern
            }
            if line.contains("Executed") {
                // "Executed 5 tests, with 0 failures" pattern
                if let match = line.range(of: #"Executed (\d+) test"#, options: .regularExpression) {
                    let numStr = line[match].split(separator: " ").dropFirst().first ?? "0"
                    passed = Int(numStr) ?? 0
                }
                if let match = line.range(of: #"(\d+) failure"#, options: .regularExpression) {
                    failed = Int(line[match].split(separator: " ").first ?? "0") ?? 0
                }
            }
        }
        passed = max(0, passed - failed)
    }

    let status = exitCode == 0 ? "✅ PASSED" : "❌ FAILED"

    return """
    🧪 Test Results (\(runner)):
    Status: \(status)
    Passed: \(passed)
    Failed: \(failed)
    Skipped: \(skipped)
    \(errors.isEmpty ? "" : "\nErrors:\n\(errors.prefix(10).map { "  • \($0)" }.joined(separator: "\n"))")
    """
}

private func parseLsLong(stdout: String, exitCode: Int32) -> String {
    let lines = stdout.components(separatedBy: "\n").filter { !$0.isEmpty }
    var entries: [String] = []
    var totalLine = ""

    for line in lines {
        if line.hasPrefix("total ") {
            totalLine = line
        } else {
            entries.append("  \(line)")
        }
    }

    return """
    📁 Directory Listing (parsed):
    \(totalLine.isEmpty ? "" : "\(totalLine)\n")Entries: \(entries.count)

    \(entries.joined(separator: "\n"))
    """
}

private func tryParseJSON(_ text: String) -> String? {
    let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
    guard trimmed.hasPrefix("{") || trimmed.hasPrefix("[") else { return nil }

    guard let data = trimmed.data(using: .utf8),
          let _ = try? JSONSerialization.jsonObject(with: data) else {
        return nil
    }

    // Re-serialize with pretty printing
    if let prettyData = try? JSONSerialization.data(withJSONObject: try! JSONSerialization.jsonObject(with: data), options: .prettyPrinted),
       let prettyString = String(data: prettyData, encoding: .utf8) {
        return prettyString
    }

    return trimmed
}
