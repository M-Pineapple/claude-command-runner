import Foundation

/// Shared terminal utilities

/// Create AppleScript for different terminal types
func createAppleScript(for terminal: TerminalConfig.TerminalType, command: String) -> String {
    switch terminal {
    case .warp, .warpPreview:
        return """
        tell application "\(terminal.rawValue)" to activate
        delay 0.5
        tell application "System Events"
            keystroke "\(command)"
        end tell
        """
        
    case .iterm2:
        return """
        tell application "iTerm"
            activate
            
            -- Get current terminal window or create new one
            if (count of windows) = 0 then
                create window with default profile
            end if
            
            tell current window
                tell current session
                    write text "\(command)"
                end tell
            end tell
        end tell
        """
        
    case .terminal:
        return """
        tell application "Terminal"
            activate
            
            -- Check if Terminal has windows
            if (count of windows) = 0 then
                do script "\(command)"
            else
                -- Use the frontmost window
                tell front window
                    do script "\(command)" in selected tab
                end tell
            end if
        end tell
        """
        
    case .alacritty:
        // Alacritty doesn't have AppleScript support, use keyboard events
        return """
        tell application "Alacritty" to activate
        delay 0.5
        tell application "System Events"
            keystroke "\(command)"
        end tell
        """
    }
}

/// Create output capture script
func createOutputCaptureScript(command: String, commandId: String) -> String {
    let outputFile = "/tmp/claude_output_\(commandId).json"
    
    return """
    #!/bin/bash
    
    # Command to execute
    COMMAND='\(command.replacingOccurrences(of: "'", with: "'\"'\"'"))'
    
    # Create a temporary file for stderr
    STDERR_FILE="/tmp/claude_stderr_\(commandId).tmp"
    
    # Execute command and capture output
    OUTPUT=$(eval "$COMMAND" 2>"$STDERR_FILE")
    EXIT_CODE=$?
    
    # Read stderr
    STDERR=$(<"$STDERR_FILE")
    rm -f "$STDERR_FILE"
    
    # Escape JSON strings
    escape_json() {
        python3 -c "import sys, json; print(json.dumps(sys.stdin.read()))" | sed 's/^"//;s/"$//'
    }
    
    # Create JSON result
    cat > "\(outputFile)" << EOF
    {
        "commandId": "\(commandId)",
        "command": "$(echo "$COMMAND" | escape_json)",
        "output": "$(echo "$OUTPUT" | escape_json)",
        "error": "$(echo "$STDERR" | escape_json)",
        "exitCode": $EXIT_CODE,
        "timestamp": "$(date -u +"%Y-%m-%dT%H:%M:%SZ")"
    }
    EOF
    
    # Signal completion by creating a marker file
    touch "\(outputFile).complete"
    
    # Also echo the output for immediate viewing in terminal
    echo "$OUTPUT"
    if [ -n "$STDERR" ]; then
        echo "$STDERR" >&2
    fi
    
    exit $EXIT_CODE
    """
}
