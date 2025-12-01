import Foundation
import MCP
import Logging

// MARK: - Command Pipeline Execution

/// Pipeline step configuration
struct PipelineStep: Codable {
    let command: String
    let onFail: FailureAction
    let name: String?
    let workingDirectory: String?
    
    enum FailureAction: String, Codable {
        case stop = "stop"           // Stop pipeline on failure
        case `continue` = "continue" // Continue to next step
        case warn = "warn"           // Log warning but continue
    }
}

/// Result of a single pipeline step
struct PipelineStepResult {
    let stepIndex: Int
    let name: String
    let command: String
    let output: String
    let error: String
    let exitCode: Int32
    let duration: TimeInterval
    let status: StepStatus
    
    enum StepStatus {
        case success
        case failed
        case skipped
    }
}

/// Complete pipeline execution result
struct PipelineResult {
    let steps: [PipelineStepResult]
    let totalDuration: TimeInterval
    let overallSuccess: Bool
    let stoppedAt: Int?
}

/// Execute a pipeline of commands with conditional logic
func handleExecutePipeline(params: CallTool.Parameters, logger: Logger, config: Configuration) async throws -> CallTool.Result {
    guard let arguments = params.arguments,
          let stepsValue = arguments["steps"],
          case .array(let stepsArray) = stepsValue else {
        return CallTool.Result(
            content: [.text("❌ Missing or invalid 'steps' parameter. Expected array of step objects.")],
            isError: true
        )
    }
    
    // Parse pipeline steps
    var steps: [PipelineStep] = []
    for (index, stepValue) in stepsArray.enumerated() {
        guard case .object(let stepObj) = stepValue,
              let commandValue = stepObj["command"],
              case .string(let command) = commandValue else {
            return CallTool.Result(
                content: [.text("❌ Invalid step at index \(index): missing 'command' string")],
                isError: true
            )
        }
        
        let onFail: PipelineStep.FailureAction
        if let onFailValue = stepObj["on_fail"],
           case .string(let onFailStr) = onFailValue {
            onFail = PipelineStep.FailureAction(rawValue: onFailStr) ?? .stop
        } else {
            onFail = .stop
        }
        
        let name: String?
        if let nameValue = stepObj["name"],
           case .string(let nameStr) = nameValue {
            name = nameStr
        } else {
            name = nil
        }
        
        let workingDir: String?
        if let dirValue = stepObj["working_directory"],
           case .string(let dirStr) = dirValue {
            workingDir = dirStr
        } else {
            workingDir = nil
        }
        
        steps.append(PipelineStep(
            command: command,
            onFail: onFail,
            name: name,
            workingDirectory: workingDir
        ))
    }
    
    if steps.isEmpty {
        return CallTool.Result(
            content: [.text("❌ Pipeline must have at least one step")],
            isError: true
        )
    }
    
    logger.info("Starting pipeline with \(steps.count) steps")
    
    // Execute pipeline
    let startTime = Date()
    var results: [PipelineStepResult] = []
    var pipelineStopped = false
    var stoppedAtIndex: Int? = nil
    
    for (index, step) in steps.enumerated() {
        if pipelineStopped {
            // Add skipped result
            results.append(PipelineStepResult(
                stepIndex: index,
                name: step.name ?? "Step \(index + 1)",
                command: step.command,
                output: "",
                error: "",
                exitCode: -1,
                duration: 0,
                status: .skipped
            ))
            continue
        }
        
        let stepName = step.name ?? "Step \(index + 1)"
        logger.info("Pipeline: Executing \(stepName) - \(step.command)")
        
        let stepStart = Date()
        
        // Execute the step
        let result = await executeCommandDirect(
            command: step.command,
            workingDirectory: step.workingDirectory,
            logger: logger
        )
        
        let stepDuration = Date().timeIntervalSince(stepStart)
        let success = result.exitCode == 0
        
        results.append(PipelineStepResult(
            stepIndex: index,
            name: stepName,
            command: step.command,
            output: result.output,
            error: result.error,
            exitCode: result.exitCode,
            duration: stepDuration,
            status: success ? .success : .failed
        ))
        
        // Handle failure based on onFail setting
        if !success {
            switch step.onFail {
            case .stop:
                logger.warning("Pipeline stopped at step \(index + 1) due to failure")
                pipelineStopped = true
                stoppedAtIndex = index
            case .continue:
                logger.info("Step \(index + 1) failed but continuing pipeline")
            case .warn:
                logger.warning("Step \(index + 1) failed: \(step.command)")
            }
        }
    }
    
    let totalDuration = Date().timeIntervalSince(startTime)
    let overallSuccess = results.allSatisfy { $0.status != .failed }
    
    // Format output
    let output = formatPipelineResult(
        results: results,
        totalDuration: totalDuration,
        overallSuccess: overallSuccess,
        stoppedAt: stoppedAtIndex
    )
    
    return CallTool.Result(content: [.text(output)], isError: !overallSuccess)
}

/// Execute a command directly and return result (internal helper)
private func executeCommandDirect(command: String, workingDirectory: String?, logger: Logger) async -> (output: String, error: String, exitCode: Int32) {
    let process = Process()
    process.executableURL = URL(fileURLWithPath: "/bin/bash")
    process.arguments = ["-c", command]
    
    if let workDir = workingDirectory {
        process.currentDirectoryURL = URL(fileURLWithPath: workDir)
    }
    
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
        
        return (output.trimmingCharacters(in: .whitespacesAndNewlines),
                error.trimmingCharacters(in: .whitespacesAndNewlines),
                process.terminationStatus)
    } catch {
        logger.error("Failed to execute command: \(error)")
        return ("", error.localizedDescription, -1)
    }
}

/// Format pipeline results for display
private func formatPipelineResult(results: [PipelineStepResult], totalDuration: TimeInterval, overallSuccess: Bool, stoppedAt: Int?) -> String {
    var output = """
    ╔══════════════════════════════════════════════════════════════╗
    ║                    PIPELINE EXECUTION RESULT                 ║
    ╚══════════════════════════════════════════════════════════════╝
    
    """
    
    for result in results {
        let statusIcon: String
        switch result.status {
        case .success: statusIcon = "✅"
        case .failed: statusIcon = "❌"
        case .skipped: statusIcon = "⏭️"
        }
        
        output += """
        \(statusIcon) \(result.name)
        ├─ Command: \(result.command)
        ├─ Exit Code: \(result.exitCode)
        ├─ Duration: \(String(format: "%.2f", result.duration))s
        """
        
        if !result.output.isEmpty {
            let truncatedOutput = result.output.count > 500 
                ? String(result.output.prefix(500)) + "... (truncated)"
                : result.output
            output += "\n├─ Output:\n\(truncatedOutput.split(separator: "\n").map { "│  \($0)" }.joined(separator: "\n"))"
        }
        
        if !result.error.isEmpty {
            output += "\n├─ Error: \(result.error)"
        }
        
        output += "\n│\n"
    }
    
    // Summary
    let successCount = results.filter { $0.status == .success }.count
    let failedCount = results.filter { $0.status == .failed }.count
    let skippedCount = results.filter { $0.status == .skipped }.count
    
    output += """
    ═══════════════════════════════════════════════════════════════
    📊 SUMMARY
    ├─ Total Steps: \(results.count)
    ├─ Successful: \(successCount)
    ├─ Failed: \(failedCount)
    ├─ Skipped: \(skippedCount)
    ├─ Total Duration: \(String(format: "%.2f", totalDuration))s
    └─ Status: \(overallSuccess ? "✅ PIPELINE SUCCEEDED" : "❌ PIPELINE FAILED")
    """
    
    if let stoppedAt = stoppedAt {
        output += "\n⚠️  Pipeline stopped at step \(stoppedAt + 1)"
    }
    
    return output
}


// MARK: - Output Streaming Mode

/// Execute with streaming output updates
func handleExecuteWithStreaming(params: CallTool.Parameters, logger: Logger, config: Configuration) async throws -> CallTool.Result {
    guard let arguments = params.arguments,
          let command = arguments["command"],
          case .string(let commandString) = command else {
        return CallTool.Result(
            content: [.text("❌ Missing or invalid 'command' parameter")],
            isError: true
        )
    }
    
    var workingDirectory: String? = nil
    if let dir = arguments["working_directory"],
       case .string(let dirString) = dir {
        workingDirectory = dirString
    }
    
    // Get update interval (default 2 seconds)
    var updateInterval: Int = 2
    if let interval = arguments["update_interval"],
       case .string(let intervalStr) = interval,
       let intervalInt = Int(intervalStr) {
        updateInterval = intervalInt
    }
    
    // Get max duration (default 120 seconds)
    var maxDuration: Int = 120
    if let maxDur = arguments["max_duration"],
       case .string(let maxDurStr) = maxDur,
       let maxDurInt = Int(maxDurStr) {
        maxDuration = maxDurInt
    }
    
    logger.info("Starting streaming execution: \(commandString)")
    logger.info("Update interval: \(updateInterval)s, Max duration: \(maxDuration)s")
    
    // Create unique output file for this execution
    let commandId = UUID().uuidString
    let outputFile = "/tmp/claude_stream_\(commandId).log"
    let exitCodeFile = "/tmp/claude_stream_\(commandId).exit"
    
    // Build command that writes to file continuously
    var fullCommand = commandString
    if let workDir = workingDirectory {
        fullCommand = "cd \"\(workDir)\" && \(commandString)"
    }
    
    // Wrap command to capture output progressively
    let wrappedCommand = """
    (\(fullCommand)) 2>&1 | while IFS= read -r line; do
        echo "$line" >> "\(outputFile)"
        echo "$line"
    done
    echo $? > "\(exitCodeFile)"
    """
    
    // Start the command in background using terminal
    let preferredTerminal = config.getPreferredTerminal() ?? TerminalConfig.getPreferredTerminal()
    let scriptContent = """
    #!/bin/bash
    \(wrappedCommand)
    """
    
    let tempScript = "/tmp/claude_stream_script_\(commandId).sh"
    try scriptContent.write(toFile: tempScript, atomically: true, encoding: .utf8)
    try FileManager.default.setAttributes([.posixPermissions: 0o755], ofItemAtPath: tempScript)
    
    // Execute via AppleScript
    let appleScript = createAppleScript(for: preferredTerminal, command: "bash \(tempScript)")
    
    let process = Process()
    process.executableURL = URL(fileURLWithPath: "/usr/bin/osascript")
    process.arguments = ["-e", appleScript]
    try process.run()
    
    // Now stream the output
    var streamedOutput = ""
    var lastReadPosition: UInt64 = 0
    let startTime = Date()
    var isComplete = false
    var exitCode: Int32? = nil
    
    // Initial message
    var updates: [String] = []
    updates.append("""
    🚀 Started streaming execution
    ├─ Command: \(commandString)
    ├─ Command ID: \(commandId)
    └─ Streaming updates every \(updateInterval)s...
    
    """)
    
    while !isComplete && Date().timeIntervalSince(startTime) < Double(maxDuration) {
        try await Task.sleep(nanoseconds: UInt64(updateInterval) * 1_000_000_000)
        
        // Check if complete
        if FileManager.default.fileExists(atPath: exitCodeFile) {
            if let exitStr = try? String(contentsOfFile: exitCodeFile).trimmingCharacters(in: .whitespacesAndNewlines),
               let code = Int32(exitStr) {
                exitCode = code
                isComplete = true
            }
        }
        
        // Read new output
        if FileManager.default.fileExists(atPath: outputFile) {
            if let fileHandle = FileHandle(forReadingAtPath: outputFile) {
                fileHandle.seek(toFileOffset: lastReadPosition)
                let newData = fileHandle.readDataToEndOfFile()
                lastReadPosition = fileHandle.offsetInFile
                fileHandle.closeFile()
                
                if let newOutput = String(data: newData, encoding: .utf8), !newOutput.isEmpty {
                    streamedOutput += newOutput
                    let elapsed = String(format: "%.1f", Date().timeIntervalSince(startTime))
                    updates.append("📝 [\(elapsed)s] New output:\n\(newOutput)")
                }
            }
        }
        
        // Progress indicator if no new output
        if updates.last?.starts(with: "📝") != true {
            let elapsed = String(format: "%.1f", Date().timeIntervalSince(startTime))
            updates.append("⏳ [\(elapsed)s] Still running...")
        }
    }
    
    // Final summary
    let totalDuration = Date().timeIntervalSince(startTime)
    let statusIcon = (exitCode ?? -1) == 0 ? "✅" : "❌"
    
    updates.append("""
    
    ═══════════════════════════════════════════════════════════════
    \(statusIcon) EXECUTION COMPLETE
    ├─ Exit Code: \(exitCode ?? -1)
    ├─ Duration: \(String(format: "%.2f", totalDuration))s
    └─ Total Output: \(streamedOutput.count) characters
    
    📋 Full Output:
    \(streamedOutput.isEmpty ? "(no output)" : streamedOutput)
    """)
    
    // Cleanup
    try? FileManager.default.removeItem(atPath: outputFile)
    try? FileManager.default.removeItem(atPath: exitCodeFile)
    try? FileManager.default.removeItem(atPath: tempScript)
    
    return CallTool.Result(
        content: [.text(updates.joined(separator: "\n"))],
        isError: (exitCode ?? -1) != 0
    )
}


// MARK: - Command Templates

/// Stored command template
struct CommandTemplate: Codable {
    let name: String
    let template: String
    let variables: [String]
    let description: String?
    let category: String?
}

/// Template storage file path
private let templatesFilePath = NSHomeDirectory() + "/.claude-command-runner/templates.json"

/// Save a command template
func handleSaveTemplate(params: CallTool.Parameters, logger: Logger) async -> CallTool.Result {
    guard let arguments = params.arguments,
          let nameValue = arguments["name"],
          case .string(let name) = nameValue,
          let templateValue = arguments["template"],
          case .string(let template) = templateValue else {
        return CallTool.Result(
            content: [.text("❌ Missing required parameters: 'name' and 'template'")],
            isError: true
        )
    }
    
    // Extract variables from template (format: {{variable_name}})
    let variablePattern = "\\{\\{([a-zA-Z_][a-zA-Z0-9_]*)\\}\\}"
    var variables: [String] = []
    if let regex = try? NSRegularExpression(pattern: variablePattern) {
        let matches = regex.matches(in: template, range: NSRange(template.startIndex..., in: template))
        variables = matches.compactMap { match in
            if let range = Range(match.range(at: 1), in: template) {
                return String(template[range])
            }
            return nil
        }
    }
    
    let description: String?
    if let descValue = arguments["description"],
       case .string(let desc) = descValue {
        description = desc
    } else {
        description = nil
    }
    
    let category: String?
    if let catValue = arguments["category"],
       case .string(let cat) = catValue {
        category = cat
    } else {
        category = nil
    }
    
    let newTemplate = CommandTemplate(
        name: name,
        template: template,
        variables: Array(Set(variables)), // Remove duplicates
        description: description,
        category: category
    )
    
    // Load existing templates
    var templates = loadTemplates()
    
    // Remove existing template with same name
    templates.removeAll { $0.name == name }
    templates.append(newTemplate)
    
    // Save templates
    do {
        let encoder = JSONEncoder()
        encoder.outputFormatting = .prettyPrinted
        let data = try encoder.encode(templates)
        
        // Ensure directory exists
        let dir = (templatesFilePath as NSString).deletingLastPathComponent
        try FileManager.default.createDirectory(atPath: dir, withIntermediateDirectories: true)
        
        try data.write(to: URL(fileURLWithPath: templatesFilePath))
        
        logger.info("Saved template: \(name)")
        
        return CallTool.Result(
            content: [.text("""
            ✅ Template saved successfully!
            
            Name: \(name)
            Template: \(template)
            Variables: \(variables.isEmpty ? "none" : variables.joined(separator: ", "))
            \(description.map { "Description: \($0)" } ?? "")
            \(category.map { "Category: \($0)" } ?? "")
            
            Use 'run_template' with name "\(name)" to execute.
            """)],
            isError: false
        )
    } catch {
        logger.error("Failed to save template: \(error)")
        return CallTool.Result(
            content: [.text("❌ Failed to save template: \(error.localizedDescription)")],
            isError: true
        )
    }
}

/// Run a saved template
func handleRunTemplate(params: CallTool.Parameters, logger: Logger, config: Configuration) async throws -> CallTool.Result {
    guard let arguments = params.arguments,
          let nameValue = arguments["name"],
          case .string(let name) = nameValue else {
        return CallTool.Result(
            content: [.text("❌ Missing required parameter: 'name'")],
            isError: true
        )
    }
    
    // Load templates
    let templates = loadTemplates()
    
    guard let template = templates.first(where: { $0.name == name }) else {
        let available = templates.map { $0.name }.joined(separator: ", ")
        return CallTool.Result(
            content: [.text("❌ Template '\(name)' not found.\nAvailable templates: \(available.isEmpty ? "none" : available)")],
            isError: true
        )
    }
    
    // Get variable values
    var command = template.template
    var variableValues: [String: String] = [:]
    
    if let varsValue = arguments["variables"],
       case .object(let varsObj) = varsValue {
        for (key, value) in varsObj {
            if case .string(let strValue) = value {
                variableValues[key] = strValue
            }
        }
    }
    
    // Check for missing variables
    let missingVars = template.variables.filter { variableValues[$0] == nil }
    if !missingVars.isEmpty {
        return CallTool.Result(
            content: [.text("""
            ❌ Missing variable values: \(missingVars.joined(separator: ", "))
            
            Template '\(name)' requires:
            \(template.variables.map { "  - {{\($0)}}" }.joined(separator: "\n"))
            
            Provide them in the 'variables' parameter.
            """)],
            isError: true
        )
    }
    
    // Substitute variables
    for (key, value) in variableValues {
        command = command.replacingOccurrences(of: "{{\(key)}}", with: value)
    }
    
    logger.info("Running template '\(name)': \(command)")
    
    // Execute the command using auto-retrieve
    let executeParams = CallTool.Parameters(
        name: "execute_with_auto_retrieve",
        arguments: ["command": .string(command)]
    )
    
    let result = try await handleExecuteWithAutoRetrieveEnhanced(params: executeParams, logger: logger, config: config)
    
    // Prepend template info
    if case .text(let resultText) = result.content.first {
        return CallTool.Result(
            content: [.text("""
            📋 Running template: \(name)
            └─ Expanded: \(command)
            
            \(resultText)
            """)],
            isError: result.isError ?? false
        )
    }
    
    return result
}

/// List available templates
func handleListTemplates(params: CallTool.Parameters, logger: Logger) async -> CallTool.Result {
    let templates = loadTemplates()
    
    if templates.isEmpty {
        return CallTool.Result(
            content: [.text("""
            📋 No saved templates yet.
            
            Use 'save_template' to create one:
            {
              "name": "my-build",
              "template": "cd {{project_dir}} && swift build",
              "description": "Build a Swift project"
            }
            """)],
            isError: false
        )
    }
    
    // Group by category
    var categorized: [String: [CommandTemplate]] = [:]
    for template in templates {
        let category = template.category ?? "Uncategorized"
        categorized[category, default: []].append(template)
    }
    
    var output = "📋 SAVED COMMAND TEMPLATES\n\n"
    
    for (category, categoryTemplates) in categorized.sorted(by: { $0.key < $1.key }) {
        output += "▸ \(category)\n"
        for template in categoryTemplates {
            output += "  • \(template.name)\n"
            output += "    Template: \(template.template)\n"
            if !template.variables.isEmpty {
                output += "    Variables: \(template.variables.joined(separator: ", "))\n"
            }
            if let desc = template.description {
                output += "    Description: \(desc)\n"
            }
            output += "\n"
        }
    }
    
    output += "Total: \(templates.count) template(s)"
    
    return CallTool.Result(content: [.text(output)], isError: false)
}

/// Load templates from disk
private func loadTemplates() -> [CommandTemplate] {
    guard FileManager.default.fileExists(atPath: templatesFilePath),
          let data = try? Data(contentsOf: URL(fileURLWithPath: templatesFilePath)),
          let templates = try? JSONDecoder().decode([CommandTemplate].self, from: data) else {
        return []
    }
    return templates
}
