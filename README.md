# Claude Command Runner

<div align="center">
  <img src="logo.png" alt="Claude Command Runner Logo" width="200">
</div>

A powerful Model Context Protocol (MCP) server that bridges Claude Desktop and terminal applications, enabling seamless command execution with intelligent output retrieval and comprehensive v3.0 features.

## 🚀 What's New in v3.0

- **Enhanced Auto-Retrieve**: Progressive delays with smart command detection
- **Rock-Solid Stability**: Fixed server crashes, runs persistently
- **Database Integration**: SQLite command history and analytics
- **Configuration System**: Customizable security and behavior settings
- **Build Intelligence**: Automatically waits longer for compilation commands

## Overview

Claude Command Runner revolutionizes the development workflow by allowing Claude to:
- Execute terminal commands directly from conversations
- Automatically capture output with intelligent timing
- Track command history and patterns
- Maintain security with configurable policies

## 🎯 Key Features

### Smart Auto-Retrieve
The `execute_with_auto_retrieve` command now intelligently detects command types and adjusts wait times:
- **Quick commands** (echo, pwd): 2-6 seconds
- **Moderate commands** (git, npm): up to 20 seconds  
- **Build commands** (swift build, make): up to 77 seconds
- **Test commands**: up to 40 seconds

### Complete Feature Set
- ✅ Two-way communication with automatic output capture
- ✅ Progressive delay system for all command types
- ✅ SQLite database for command history
- ✅ Configurable security policies
- ✅ Multi-terminal support (Warp recommended)
- ✅ Command suggestions based on history

## 📊 Why Warp Terminal?

For the best experience, we recommend [Warp Terminal](https://app.warp.dev/referral/G9W3EY):

| Feature | Warp | Terminal.app | iTerm2 |
|---------|------|--------------|---------|
| Auto Output Capture | ✅ | ❌ | ❌ |
| Command History Integration | ✅ | ❌ | ❌ |
| AI-Powered Features | ✅ | ❌ | ❌ |
| Modern UI/UX | ✅ | ⚠️ | ⚠️ |

> 💡 **Get Warp Free**: [Download Warp Terminal](https://app.warp.dev/referral/G9W3EY) - It's free and makes Claude Command Runner significantly more powerful!

## Installation

### Prerequisites
- macOS 13.0 or later
- Swift 6.0+ (Xcode 16+)
- Claude Desktop
- A supported terminal ([Warp](https://app.warp.dev/referral/G9W3EY) strongly recommended)

### Quick Install

1. Clone and build:
```bash
git clone https://github.com/yourusername/claude-command-runner.git
cd claude-command-runner
./build.sh
```

2. Configure Claude Desktop by adding to your MCP settings:
```json
{
  "claude-command-runner": {
    "command": "/path/to/claude-command-runner/.build/release/claude-command-runner",
    "args": ["--port", "9876"],
    "env": {}
  }
}
```

3. Restart Claude Desktop

## Usage

### Available Tools

1. **execute_command** - Execute with manual output retrieval
2. **execute_with_auto_retrieve** - Execute with intelligent auto-retrieval ⭐
3. **get_command_output** - Manually retrieve command output
4. **preview_command** - Preview without executing
5. **suggest_command** - Get command suggestions

### Example Workflow

```
You: "Build my Swift project"
Claude: [Executes: swift build]
[Waits intelligently up to 77 seconds]
Claude: "Build completed successfully! Here's the output..."
```

## Configuration

The configuration file is located at `~/.claude-command-runner/config.json`:

```json
{
  "terminal": {
    "preferred": "auto",
    "fallbackOrder": ["Warp", "WarpPreview", "iTerm", "Terminal"]
  },
  "security": {
    "blockedCommands": ["rm -rf /", "format"],
    "maxCommandLength": 1000
  },
  "history": {
    "enabled": true,
    "maxEntries": 10000
  }
}
```

## 🤔 Frequently Asked Questions

### Q: Why does the server crash sometimes?
**A:** This was a major issue in earlier versions. v3.0 completely fixes server stability by removing problematic background tasks and implementing a safer progressive delay system.

### Q: How long will auto-retrieve wait for my command?
**A:** It depends on the command type:
- Simple commands: 6 seconds
- Git/npm commands: 20 seconds
- Build commands: 77 seconds
- Unknown commands: 30 seconds

### Q: Can I use this with Terminal.app or iTerm2?
**A:** Yes, basic command execution works with any terminal. However, automatic output capture and advanced features require Warp Terminal. [Get Warp free here](https://app.warp.dev/referral/G9W3EY).

### Q: Is it secure to let Claude run commands?
**A:** Yes! Every command requires manual approval (pressing Enter), and you can configure blocked commands and patterns in the config file. Claude cannot execute anything without your explicit consent.

### Q: What happens if my build takes longer than 77 seconds?
**A:** The auto-retrieve will timeout and provide the command ID. You can then use `get_command_output` with that ID to retrieve the results when ready.

### Q: Where is my command history stored?
**A:** In an SQLite database at `~/.claude-command-runner/claude_commands.db`. It tracks all commands, outputs, exit codes, and execution times.

### Q: Can I contribute to this project?
**A:** Absolutely! Fork the repo, make your changes, and submit a PR. Check out our contributing guidelines below.

### Q: Why do you recommend Warp so strongly?
**A:** Warp provides APIs that enable features impossible with other terminals:
- Automatic output capture without polling
- Integrated command history
- Modern async architecture
- Plus, it's free and helps support the project through their referral program

## 🛠️ Troubleshooting

### MCP Not Responding
1. Check if the server is running: `lsof -i :9876`
2. Restart Claude Desktop
3. Rebuild with `./build.sh`

### Commands Not Appearing in Terminal
1. Ensure Warp/WarpPreview is running
2. Check Claude Desktop logs for errors
3. Verify your MCP configuration path

### Auto-Retrieve Not Working
1. Ensure you're using `execute_with_auto_retrieve` (not `execute_command`)
2. Check if command output file exists: `ls /tmp/claude_output_*.json`
3. For long commands, wait for timeout message then use manual retrieval

## Architecture

```
┌─────────────────┐         ┌──────────────────┐         ┌────────────────┐
│ Claude Desktop  │ ←────→  │ Command Runner   │ ←────→  │ Warp Terminal  │
│                 │  MCP    │ MCP Server       │ Script  │                │
│ • Send commands │         │ • Port 9876      │         │ • Execute      │
│ • Auto-retrieve │         │ • Progress Delay │         │ • Capture      │
│ • Get output    │         │ • SQLite DB      │         │ • Return       │
└─────────────────┘         └──────────────────┘         └────────────────┘
```

## Contributing

We love contributions! Here's how:

1. Fork the repository
2. Create a feature branch (`git checkout -b feature/amazing-feature`)
3. Commit your changes (`git commit -m 'Add amazing feature'`)
4. Push to the branch (`git push origin feature/amazing-feature`)
5. Open a Pull Request

### Development Setup
```bash
git clone https://github.com/yourusername/claude-command-runner.git
cd claude-command-runner
swift package resolve
swift build
```

## 💖 Support This Project

If Claude Command Runner has helped enhance your development workflow or saved you time with intelligent command execution, consider supporting its development:

<a href="https://www.buymeacoffee.com/mpineapple" target="_blank"><img src="https://cdn.buymeacoffee.com/buttons/v2/default-yellow.png" alt="Buy Me A Coffee" style="height: 60px !important;width: 217px !important;" ></a>

Your support helps me:
- Maintain and improve Claude Command Runner with new features
- Keep the project open-source and free for everyone
- Dedicate more time to addressing user requests and bug fixes
- Explore new terminal integrations and command intelligence

Thank you for considering supporting my work! 🙏

## License

MIT License - see [LICENSE](LICENSE) file for details

---

**Built with ❤️ by Rogers and Claude**

*If you find this project helpful, give it a ⭐ and try [Warp Terminal](https://app.warp.dev/referral/G9W3EY)!*
