# Claude Command Runner for Warp Terminal 
![image-2](https://github.com/user-attachments/assets/c3110bf2-3408-451c-9d0b-a2f64f7cd19e)
A powerful Model Context Protocol (MCP) server that bridges Claude Desktop and Warp Terminal, enabling seamless command execution with two-way communication and automatic output retrieval.

## 🚀 Version 2.1 Features

- **Two-Way Communication**: Execute commands and automatically receive their output back in Claude
- **Auto-Retrieve Mode**: No more manual output checking - Claude proactively gets command results
- **Security First**: Multi-layered security with manual approval and macOS permission system
- **Warp Preview Support**: Full compatibility with both Warp Terminal and Warp Preview

## Overview

Claude Command Runner revolutionizes the development workflow by allowing you to:
- Execute terminal commands directly from Claude Desktop
- Automatically capture command output, errors, and exit codes
- Get immediate feedback on compilation errors and test results
- Maintain full security with required user approval for all commands

**Key Benefits**:
- ✅ Uses YOUR Claude subscription (not Warp's AI credits)
- ✅ Seamless integration between Claude Desktop and terminal
- ✅ Automatic output retrieval eliminates workflow friction
- ✅ Full command history and output tracking

## 📊 Terminal Compatibility

### Feature Comparison by Terminal

| Feature | Warp | Terminal.app | iTerm2 | Alacritty | Description |
|---------|------|--------------|---------|-----------|-------------|
| **Send Commands** | ✅ | ✅ | ✅ | ✅ | Basic command sending to terminal |
| **Auto Output Capture** | ✅ | ❌ | ❌ | ❌ | Automatically retrieve command results |
| **Exit Code Tracking** | ✅ | ❌ | ❌ | ❌ | Know if commands succeeded or failed |
| **Command Duration** | ✅ | ❌ | ❌ | ❌ | Track how long commands take |
| **History Integration** | ✅ | ❌ | ❌ | ❌ | Access and learn from past commands |
| **Smart Suggestions** | ✅ | ⚠️ | ⚠️ | ⚠️ | AI-powered command suggestions |
| **Analytics** | ✅ | ❌ | ❌ | ❌ | Command usage statistics |

**Legend:** ✅ Full Support | ⚠️ Limited Support | ❌ Not Supported

> **💡 Recommendation:** For the best experience with all features, use **Warp Terminal**. Other terminals provide basic command sending only.

## Installation

### Prerequisites
- macOS 13.0 or later
- Swift 6.0+ (Xcode 16+)
- Claude Desktop
- A supported terminal:
  - **Warp Terminal** (recommended for full features)
  - Terminal.app (basic support)
  - iTerm2 (basic support)
  - Alacritty (basic support)

### Quick Install

1. Clone the repository:
```bash
git clone https://github.com/M-Pineapple/claude-command-runner.git
cd claude-command-runner
```

2. Build the project:
```bash
./build.sh
```

3. Configure Claude Desktop:
   - Open Claude Desktop settings
   - Add the MCP server configuration (see Configuration section)

## Configuration

### Claude Desktop Configuration

Add to your Claude Desktop MCP settings:

```json
{
  "claude-command-runner": {
    "command": "/path/to/claude-command-runner/.build/release/claude-command-runner",
    "args": ["--port", "9876"],
    "env": {}
  }
}
```

### Warp Terminal Configuration

Edit `~/.claude-command-runner/config.json` to set your preferred terminal:

```json
{
  "terminal": {
    "preferred": "Warp",  // Options: "Warp", "Terminal.app", "iTerm2", "Alacritty"
    "fallbackOrder": ["Warp", "iTerm2", "Terminal.app", "Alacritty"]
  }
}
```

### Command Line Options

```bash
claude-command-runner [options]

OPTIONS:
  -p, --port <port>        Port for command receiver (default: 9876)
  -l, --log-level <level>  Log level: debug, info, warning, error (default: info)
  --verbose                Enable verbose logging
  -h, --help               Show help information
```

## Usage

### Available Tools

1. **execute_command**: Executes a command and captures output
   - `command` (string) - The command to execute
   - `working_directory` (string, optional) - Working directory
   
2. **execute_with_auto_retrieve** ⭐ NEW: Executes and automatically returns output
   - `command` (string) - The command to execute
   - `working_directory` (string, optional) - Working directory
   
3. **get_command_output**: Manually retrieve command output
   - `command_id` (string) - Command ID or "last" for most recent
   
4. **preview_command**: Preview a command without executing
   - `command` (string) - The command to preview

### Basic Workflow

1. Claude sends command → Warp Preview displays it
2. You review and press Enter → Command executes
3. Claude automatically receives output → Responds proactively

### Example: Building a Swift Project

```
Claude: "Let me build your project and check for errors"
[Executes: swift build]

User: [Presses Enter in Warp]

Claude: "I see there are 3 compilation errors:
- Line 42: Missing semicolon
- Line 78: Undefined variable 'config'
- Line 123: Type mismatch
Let me fix these for you..."
```

## Security Model

### Multi-Layered Protection

1. **User Approval Required**
   - Every command requires manual Enter press
   - Commands are visible before execution
   - No silent or background execution

2. **macOS Security Integration**
   - sudo commands require password
   - System directories protected
   - Respects Full Disk Access settings

3. **Application Sandboxing**
   - Warp Preview runs without Full Disk Access
   - Limited to user-accessible directories
   - Cannot bypass system permissions

## Architecture

```
┌─────────────────┐         ┌──────────────────┐         ┌────────────────┐
│ Claude Desktop  │ ←────→  │ Command Runner   │ ←────→  │ Warp Preview   │
│                 │         │ MCP Server       │         │                │
│ • Send commands │         │ • Port 9876      │         │ • Display      │
│ • Get output    │         │ • JSON output    │         │ • User approve │
│ • Auto-retrieve │         │ • Two-way comm   │         │ • Execute      │
└─────────────────┘         └──────────────────┘         └────────────────┘
```

## Advanced Features

### Auto-Retrieve Mode
The `execute_with_auto_retrieve` tool revolutionizes the workflow:
- Monitors for command completion (up to 2 minutes)
- Automatically retrieves output when ready
- Perfect for long-running builds and tests
- Shows progress for build commands

### Output Format
Commands return structured data including:
- Full command string
- Exit code
- Stdout and stderr separately
- Execution timestamp
- Working directory used

## Troubleshooting

### Common Issues

1. **"Can't get application WarpPreview"**
   - Ensure you're using Warp Preview (not regular Warp)
   - Check application name in `/Applications/`

2. **Output not retrieved**
   - Restart Claude Desktop after updates
   - Check `/tmp/claude_output_*.json` files exist
   - Verify build completed successfully

3. **Commands not appearing**
   - Verify MCP server is running: `lsof -i :9876`
   - Check Claude Desktop MCP configuration
   - Review logs with `--verbose` flag

## Future Roadmap

- [ ] Real-time notifications via MCP protocol
- [ ] Command history browser
- [ ] Persistent output storage
- [ ] Multi-terminal support
- [ ] Custom command shortcuts
- [ ] Integration with other terminal emulators

## Contributing

We welcome contributions! Please:

1. Fork the repository
2. Create a feature branch (`git checkout -b feature/amazing-feature`)
3. Commit your changes (`git commit -m 'Add amazing feature'`)
4. Push to the branch (`git push origin feature/amazing-feature`)
5. Open a Pull Request

## License

MIT License - see LICENSE file for details

---

**Built with ❤️ by 🍍**
