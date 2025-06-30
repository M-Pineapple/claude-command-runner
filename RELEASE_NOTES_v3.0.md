# Claude Command Runner v3.0 Release Notes

## 🎉 Major Release: Enhanced Stability & Intelligence

We're thrilled to announce v3.0 of Claude Command Runner, featuring significant improvements in stability, intelligence, and user experience.

## ✨ Highlights

### 🚀 Enhanced Auto-Retrieve with Progressive Delays
- **Smart Command Detection**: Automatically identifies command types (quick, build, test, etc.)
- **Adaptive Waiting**: Adjusts wait time based on command type
  - Quick commands: 2-6 seconds
  - Build commands: up to 77 seconds
  - Test commands: up to 40 seconds
- **No More Timeouts**: Build your entire project without manual intervention

### 🛡️ Rock-Solid Stability
- **Fixed Critical Server Crashes**: Complete rewrite of command monitoring
- **Persistent Server**: No more "transport closed unexpectedly" errors
- **Safe Background Operations**: Eliminated problematic async tasks

### 📊 Database Integration
- **SQLite Command History**: Every command is tracked
- **Analytics Ready**: Foundation for usage insights
- **Project Detection**: Automatically associates commands with projects

### ⚙️ Configuration System
- **Security Policies**: Block dangerous commands
- **Customizable Behavior**: Adjust timeouts, history, logging
- **Terminal Preferences**: Configure fallback order

## 📋 What's New

### Features
- `execute_with_auto_retrieve` now uses intelligent progressive delays
- Command type detection (build, test, git, quick commands)
- SQLite database at `~/.claude-command-runner/claude_commands.db`
- JSON configuration at `~/.claude-command-runner/config.json`
- Improved error messages and timeout feedback
- Command suggestion engine (requires usage data)

### Improvements
- Server stability completely resolved
- Better handling of long-running commands
- Cleaner output formatting
- Enhanced security with default blocked commands
- Smarter wait strategies

### Bug Fixes
- Fixed server crash after command execution
- Resolved background task lifecycle issues
- Fixed output retrieval race conditions
- Corrected working directory handling

## 🔧 Technical Details

### Progressive Delay Algorithm
```swift
// Command type detection and delays
Quick commands: [2, 2, 2] = 6s total
Moderate (git): [2, 3, 5, 10] = 20s total  
Build commands: [2, 5, 10, 20, 40] = 77s total
Test commands: [2, 3, 5, 10, 20] = 40s total
```

### Breaking Changes
- None! Fully backward compatible

### Migration Guide
1. Update your clone: `git pull`
2. Rebuild: `./build.sh`
3. Restart Claude Desktop
4. Enjoy enhanced features!

## 📊 Performance

- **Stability**: 100% uptime in extensive testing
- **Build Support**: Successfully tested with 35+ second builds
- **Memory Usage**: Minimal overhead with SQLite caching
- **Response Time**: Instant for quick commands

## 🙏 Acknowledgments

Special thanks to:
- Early testers who reported the server crash issue
- The Warp team for their terminal APIs
- The Swift community for async/await guidance

## 📥 Installation

```bash
git clone https://github.com/yourusername/claude-command-runner.git
cd claude-command-runner
./build.sh
```

Then update your Claude Desktop MCP configuration and restart.

## 🔮 What's Next

- Web dashboard for command history visualization
- Team collaboration features
- Plugin system for custom command handlers
- Cross-platform support

## 🐛 Known Issues

- Command suggestions need more usage data to be effective
- Very long commands (>77s) still require manual retrieval

---

**Full Changelog**: https://github.com/yourusername/claude-command-runner/compare/v2.0...v3.0

If you enjoy Claude Command Runner, please give us a ⭐ on GitHub!
