import Foundation
import MCP
import Logging

// MARK: - Warp Code Integration Tools
public struct WarpCodeTools {
    static let editCodeTool = Tool(
        name: "edit_code",
        description: "Opens and edits code files directly in Warp Code with syntax highlighting",
        inputSchema: .object([
            "type": .string("object"),
            "properties": .object([
                "file_path": .object([
                    "type": .string("string"),
                    "description": .string("Path to the code file")
                ]),
                "line_number": .object([
                    "type": .string("integer"),
                    "description": .string("Optional line number to jump to")
                ]),
                "preview_changes": .object([
                    "type": .string("string"),
                    "description": .string("Optional code changes to preview")
                ])
            ]),
            "required": .array([.string("file_path")])
        ])
    )
    
    static let createSwiftFileTool = Tool(
        name: "create_swift_file",
        description: "Creates a new Swift file with appropriate template in Warp Code",
        inputSchema: .object([
            "type": .string("object"),
            "properties": .object([
                "file_name": .object([
                    "type": .string("string"),
                    "description": .string("Name of the Swift file to create")
                ]),
                "template_type": .object([
                    "type": .string("string"),
                    "description": .string("Type: SwiftUI, UIKit, Model, Protocol, Extension, Test")
                ]),
                "initial_content": .object([
                    "type": .string("string"),
                    "description": .string("Optional initial code content")
                ])
            ]),
            "required": .array([.string("file_name"), .string("template_type")])
        ])
    )
    
    static let multiFileRefactorTool = Tool(
        name: "refactor_multiple_files",
        description: "Refactor code across multiple Swift files simultaneously",
        inputSchema: .object([
            "type": .string("object"),
            "properties": .object([
                "files": .object([
                    "type": .string("array"),
                    "description": .string("List of file paths to refactor")
                ]),
                "operation": .object([
                    "type": .string("string"),
                    "description": .string("Type: rename_symbol, update_imports, convert_to_async, extract_protocol")
                ]),
                "parameters": .object([
                    "type": .string("object"),
                    "description": .string("Operation-specific parameters")
                ])
            ]),
            "required": .array([.string("files"), .string("operation")])
        ])
    )
    
    static let watchBuildTool = Tool(
        name: "watch_build",
        description: "Watch for compilation errors in real-time as you edit",
        inputSchema: .object([
            "type": .string("object"),
            "properties": .object([
                "project_path": .object([
                    "type": .string("string"),
                    "description": .string("Path to .xcodeproj or Package.swift")
                ]),
                "scheme": .object([
                    "type": .string("string"),
                    "description": .string("Build scheme or target name")
                ]),
                "filter": .object([
                    "type": .string("string"),
                    "description": .string("Filter: errors_only, warnings_only, all")
                ])
            ]),
            "required": .array([.string("project_path")])
        ])
    )
}

// MARK: - Warp Code Handlers
public func handleEditCode(params: CallTool.Parameters, logger: Logger) async throws -> CallTool.Result {
    guard let arguments = params.arguments,
          let filePath = arguments["file_path"],
          case .string(let filePathString) = filePath else {
        return CallTool.Result(
            content: [.text("❌ Missing or invalid 'file_path' parameter")],
            isError: true
        )
    }
    
    var lineNumber: Int? = nil
    if let line = arguments["line_number"],
       case .integer(let lineInt) = line {
        lineNumber = lineInt
    }
    
    var previewChanges: String? = nil
    if let preview = arguments["preview_changes"],
       case .string(let previewString) = preview {
        previewChanges = previewString
    }
    
    logger.info("Opening \(filePathString) in Warp Code")
    
    // Build the Warp Code command
    var command = "warp code \"\(filePathString)\""
    
    if let line = lineNumber {
        command += " --goto \(line)"
    }
    
    // If we have preview changes, create a diff view
    if let changes = previewChanges {
        let diffCommand = """
        # Opening file in Warp Code and showing proposed changes
        \(command)
        
        # Proposed changes:
        cat << 'CHANGES'
        \(changes)
        CHANGES
        """
        
        return CallTool.Result(
            content: [.text("""
            📝 Opening in Warp Code:
            File: \(filePathString)
            \(lineNumber.map { "Line: \($0)" } ?? "")
            
            Proposed Changes:
            \(changes)
            
            Use the execute_command tool to apply these changes.
            """)],
            isError: false
        )
    }
    
    return CallTool.Result(
        content: [.text("""
        📝 Warp Code Command Ready:
        \(command)
        
        This will open the file in Warp Code's editor with syntax highlighting.
        \(lineNumber.map { "Jumping to line \($0)" } ?? "")
        """)],
        isError: false
    )
}

public func handleCreateSwiftFile(params: CallTool.Parameters, logger: Logger) async throws -> CallTool.Result {
    guard let arguments = params.arguments,
          let fileName = arguments["file_name"],
          case .string(let fileNameString) = fileName,
          let templateType = arguments["template_type"],
          case .string(let templateTypeString) = templateType else {
        return CallTool.Result(
            content: [.text("❌ Missing required parameters")],
            isError: true
        )
    }
    
    var initialContent: String? = nil
    if let content = arguments["initial_content"],
       case .string(let contentString) = content {
        initialContent = contentString
    }
    
    // Generate template based on type
    let template = generateSwiftTemplate(
        type: templateTypeString,
        fileName: fileNameString,
        customContent: initialContent
    )
    
    let createCommand = """
    cat << 'EOF' > "\(fileNameString)"
    \(template)
    EOF
    
    warp code "\(fileNameString)"
    """
    
    return CallTool.Result(
        content: [.text("""
        🆕 Creating Swift File:
        Name: \(fileNameString)
        Template: \(templateTypeString)
        
        Command to execute:
        \(createCommand)
        
        This will create the file and open it in Warp Code.
        """)],
        isError: false
    )
}

// MARK: - Template Generation
private func generateSwiftTemplate(type: String, fileName: String, customContent: String?) -> String {
    let structName = fileName
        .replacingOccurrences(of: ".swift", with: "")
        .split(separator: "_")
        .map { $0.prefix(1).uppercased() + $0.dropFirst() }
        .joined()
    
    if let custom = customContent {
        return custom
    }
    
    switch type.lowercased() {
    case "swiftui":
        return """
        import SwiftUI
        
        struct \(structName): View {
            var body: some View {
                VStack {
                    Text("Hello, World!")
                        .font(.title)
                        .padding()
                }
            }
        }
        
        #Preview {
            \(structName)()
        }
        """
        
    case "uikit":
        return """
        import UIKit
        
        class \(structName): UIViewController {
            
            override func viewDidLoad() {
                super.viewDidLoad()
                setupUI()
            }
            
            private func setupUI() {
                view.backgroundColor = .systemBackground
                // Add your UI setup here
            }
        }
        """
        
    case "model":
        return """
        import Foundation
        
        struct \(structName): Codable, Identifiable {
            let id = UUID()
            
            // Add your properties here
        }
        """
        
    case "protocol":
        return """
        import Foundation
        
        protocol \(structName) {
            // Add protocol requirements here
        }
        
        extension \(structName) {
            // Add default implementations here
        }
        """
        
    case "test":
        return """
        import XCTest
        @testable import YourAppModule
        
        final class \(structName): XCTestCase {
            
            override func setUpWithError() throws {
                // Setup code here
            }
            
            override func tearDownWithError() throws {
                // Cleanup code here
            }
            
            func testExample() throws {
                // Arrange
                
                // Act
                
                // Assert
                XCTAssertTrue(true)
            }
        }
        """
        
    default:
        return """
        import Foundation
        
        // \(structName)
        // Created on \(Date())
        
        """
    }
}

// MARK: - Multi-file Refactoring
public func handleMultiFileRefactor(params: CallTool.Parameters, logger: Logger) async throws -> CallTool.Result {
    guard let arguments = params.arguments,
          let files = arguments["files"],
          case .array(let filesArray) = files,
          let operation = arguments["operation"],
          case .string(let operationString) = operation else {
        return CallTool.Result(
            content: [.text("❌ Missing required parameters")],
            isError: true
        )
    }
    
    let fileList = filesArray.compactMap { file -> String? in
        guard case .string(let path) = file else { return nil }
        return path
    }
    
    // Build refactoring command based on operation
    let refactorCommand: String
    
    switch operationString.lowercased() {
    case "rename_symbol":
        refactorCommand = buildRenameCommand(files: fileList)
    case "update_imports":
        refactorCommand = buildUpdateImportsCommand(files: fileList)
    case "convert_to_async":
        refactorCommand = buildAsyncConversionCommand(files: fileList)
    default:
        refactorCommand = "echo 'Unsupported refactoring operation'"
    }
    
    return CallTool.Result(
        content: [.text("""
        🔧 Multi-file Refactoring:
        Operation: \(operationString)
        Files: \(fileList.count) files
        
        Command:
        \(refactorCommand)
        """)],
        isError: false
    )
}

// MARK: - Build Watching
public func handleWatchBuild(params: CallTool.Parameters, logger: Logger) async throws -> CallTool.Result {
    guard let arguments = params.arguments,
          let projectPath = arguments["project_path"],
          case .string(let projectPathString) = projectPath else {
        return CallTool.Result(
            content: [.text("❌ Missing project_path parameter")],
            isError: true
        )
    }
    
    let scheme = arguments["scheme"].flatMap { arg -> String? in
        guard case .string(let s) = arg else { return nil }
        return s
    }
    
    let filter = arguments["filter"].flatMap { arg -> String? in
        guard case .string(let f) = arg else { return nil }
        return f
    } ?? "all"
    
    // Create build watch script
    let watchScript = """
    #!/bin/bash
    
    echo "🔄 Starting build watcher for \(projectPathString)"
    echo "Press Ctrl+C to stop"
    
    # Function to build and capture errors
    build_and_report() {
        echo "\\n📦 Building..."
        
        xcodebuild \
            -project "\(projectPathString)" \
            \(scheme.map { "-scheme \"\\($0)\"" } ?? "") \
            -configuration Debug \
            build 2>&1 | \
        awk '/error:|warning:/ {
            if (/error:/) {
                printf "❌ %s\\n", $0
            } else {
                printf "⚠️  %s\\n", $0
            }
        }'
        
        if [ ${PIPESTATUS[0]} -eq 0 ]; then
            echo "✅ Build succeeded!"
        else
            echo "❌ Build failed!"
        fi
    }
    
    # Initial build
    build_and_report
    
    # Watch for changes
    fswatch -o *.swift | while read num; do
        build_and_report
    done
    """
    
    return CallTool.Result(
        content: [.text("""
        👁️ Build Watch Script:
        
        \(watchScript)
        
        Save this as 'watch_build.sh' and run:
        chmod +x watch_build.sh && ./watch_build.sh
        
        This will continuously monitor your Swift files and show compilation errors in real-time.
        """)],
        isError: false
    )
}

// MARK: - Helper Functions
private func buildRenameCommand(files: [String]) -> String {
    return """
    # Open all files in Warp Code for renaming
    \(files.map { "warp code \"\\($0)\"" }.joined(separator: " && "))
    
    echo "Files opened in Warp Code. Use Find & Replace across files."
    """
}

private func buildUpdateImportsCommand(files: [String]) -> String {
    return """
    # Update imports across multiple files
    for file in \(files.joined(separator: " ")); do
        echo "Updating imports in $file"
        # Add your import update logic here
    done
    """
}

private func buildAsyncConversionCommand(files: [String]) -> String {
    return """
    # Convert completion handlers to async/await
    echo "Converting to async/await in:"
    \(files.map { "echo \"  - \\($0)\"" }.joined(separator: "\n"))
    
    # This would require more complex AST manipulation
    echo "Manual review required in Warp Code"
    """
}
