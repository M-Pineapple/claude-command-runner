import Foundation
import MCP
import Logging

// MARK: - v5.0.0: Shell Environment Snapshots

/// Actor for thread-safe environment snapshot storage
actor EnvironmentStore {
    private var snapshots: [String: EnvironmentSnapshotData] = [:]

    func store(name: String, snapshot: EnvironmentSnapshotData) {
        snapshots[name] = snapshot
    }

    func retrieve(name: String) -> EnvironmentSnapshotData? {
        return snapshots[name]
    }

    func list() -> [(name: String, timestamp: Date, count: Int)] {
        return snapshots.map { (name: $0.key, timestamp: $0.value.timestamp, count: $0.value.variables.count) }
            .sorted { $0.timestamp > $1.timestamp }
    }

    func remove(name: String) -> Bool {
        return snapshots.removeValue(forKey: name) != nil
    }
}

struct EnvironmentSnapshotData: Codable {
    let name: String
    let variables: [String: String]
    let timestamp: Date
    let directory: String
}

/// Global environment store
let environmentStore = EnvironmentStore()

// MARK: - Tool Handlers

/// Handle capture_environment tool — takes a snapshot of current shell environment
func handleCaptureEnvironment(params: CallTool.Parameters, logger: Logger) async -> CallTool.Result {
    guard let arguments = params.arguments,
          let nameValue = arguments["name"],
          case .string(let name) = nameValue else {
        return CallTool.Result(
            content: [.text("Missing or invalid 'name' parameter — provide a name for this snapshot")],
            isError: true
        )
    }

    var workingDirectory: String?
    if let dir = arguments["working_directory"],
       case .string(let dirString) = dir {
        workingDirectory = dirString
    }

    logger.info("Capturing environment snapshot: \(name)")

    // Build and execute env capture script
    var script = ""
    if let dir = workingDirectory {
        script += "cd \"\(dir)\" 2>/dev/null; "
    }
    script += "env | sort"

    let process = Process()
    process.executableURL = URL(fileURLWithPath: "/bin/bash")
    process.arguments = ["-c", script]

    let outputPipe = Pipe()
    process.standardOutput = outputPipe
    process.standardError = Pipe()

    do {
        try process.run()
        process.waitUntilExit()

        let outputData = outputPipe.fileHandleForReading.readDataToEndOfFile()
        let output = String(data: outputData, encoding: .utf8) ?? ""

        // Parse environment variables
        var variables: [String: String] = [:]
        for line in output.components(separatedBy: "\n") {
            let parts = line.split(separator: "=", maxSplits: 1)
            if parts.count == 2 {
                variables[String(parts[0])] = String(parts[1])
            }
        }

        let cwd = variables["PWD"] ?? workingDirectory ?? "unknown"

        let snapshot = EnvironmentSnapshotData(
            name: name,
            variables: variables,
            timestamp: Date(),
            directory: cwd
        )

        await environmentStore.store(name: name, snapshot: snapshot)

        // Optionally persist to disk
        persistSnapshot(snapshot, logger: logger)

        return CallTool.Result(
            content: [.text("""
            ✅ Environment snapshot captured: "\(name)"
            • Variables: \(variables.count)
            • Directory: \(cwd)
            • Timestamp: \(ISO8601DateFormatter().string(from: snapshot.timestamp))

            💡 Use 'diff_environment' with two snapshot names to compare.
            """)],
            isError: false
        )
    } catch {
        logger.error("Failed to capture environment: \(error)")
        return CallTool.Result(
            content: [.text("❌ Failed to capture environment: \(error.localizedDescription)")],
            isError: true
        )
    }
}

/// Handle diff_environment tool — compares two snapshots
func handleDiffEnvironment(params: CallTool.Parameters, logger: Logger) async -> CallTool.Result {
    guard let arguments = params.arguments,
          let fromValue = arguments["from"],
          case .string(let fromName) = fromValue,
          let toValue = arguments["to"],
          case .string(let toName) = toValue else {
        return CallTool.Result(
            content: [.text("Missing parameters: 'from' and 'to' snapshot names are required")],
            isError: true
        )
    }

    logger.info("Diffing environments: \(fromName) → \(toName)")

    guard let fromSnapshot = await environmentStore.retrieve(name: fromName) else {
        return CallTool.Result(
            content: [.text("❌ Snapshot '\(fromName)' not found. Use 'capture_environment' first.")],
            isError: true
        )
    }

    guard let toSnapshot = await environmentStore.retrieve(name: toName) else {
        return CallTool.Result(
            content: [.text("❌ Snapshot '\(toName)' not found. Use 'capture_environment' first.")],
            isError: true
        )
    }

    // Compute diff
    let fromVars = fromSnapshot.variables
    let toVars = toSnapshot.variables

    let allKeys = Set(fromVars.keys).union(Set(toVars.keys)).sorted()

    var added: [String] = []
    var removed: [String] = []
    var changed: [(key: String, from: String, to: String)] = []
    var unchanged = 0

    for key in allKeys {
        let fromVal = fromVars[key]
        let toVal = toVars[key]

        if fromVal == nil && toVal != nil {
            added.append("\(key)=\(toVal!)")
        } else if fromVal != nil && toVal == nil {
            removed.append("\(key)=\(fromVal!)")
        } else if fromVal != toVal {
            changed.append((key: key, from: fromVal!, to: toVal!))
        } else {
            unchanged += 1
        }
    }

    let formatter = ISO8601DateFormatter()

    var output = """
    🔄 Environment Diff: "\(fromName)" → "\(toName)"
    From: \(formatter.string(from: fromSnapshot.timestamp)) (\(fromSnapshot.directory))
    To:   \(formatter.string(from: toSnapshot.timestamp)) (\(toSnapshot.directory))

    Summary: +\(added.count) added, -\(removed.count) removed, ~\(changed.count) changed, \(unchanged) unchanged
    """

    if !added.isEmpty {
        output += "\n\n➕ Added (\(added.count)):"
        for item in added.prefix(20) {
            output += "\n  \(item)"
        }
        if added.count > 20 { output += "\n  ... and \(added.count - 20) more" }
    }

    if !removed.isEmpty {
        output += "\n\n➖ Removed (\(removed.count)):"
        for item in removed.prefix(20) {
            output += "\n  \(item)"
        }
        if removed.count > 20 { output += "\n  ... and \(removed.count - 20) more" }
    }

    if !changed.isEmpty {
        output += "\n\n🔀 Changed (\(changed.count)):"
        for item in changed.prefix(20) {
            let fromTrunc = item.from.count > 60 ? String(item.from.prefix(60)) + "..." : item.from
            let toTrunc = item.to.count > 60 ? String(item.to.prefix(60)) + "..." : item.to
            output += "\n  \(item.key):"
            output += "\n    - \(fromTrunc)"
            output += "\n    + \(toTrunc)"
        }
        if changed.count > 20 { output += "\n  ... and \(changed.count - 20) more" }
    }

    return CallTool.Result(
        content: [.text(output)],
        isError: false
    )
}

// MARK: - Persistence

private func persistSnapshot(_ snapshot: EnvironmentSnapshotData, logger: Logger) {
    let dir = FileManager.default.homeDirectoryForCurrentUser
        .appendingPathComponent(".claude-command-runner")
        .appendingPathComponent("snapshots")

    try? FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)

    let file = dir.appendingPathComponent("\(snapshot.name).json")
    let encoder = JSONEncoder()
    encoder.outputFormatting = .prettyPrinted
    encoder.dateEncodingStrategy = .iso8601

    if let data = try? encoder.encode(snapshot) {
        try? data.write(to: file)
        logger.debug("Snapshot persisted to \(file.path)")
    }
}
