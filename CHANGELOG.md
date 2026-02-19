# Changelog

All notable changes to Claude Command Runner will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.0.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [5.0.2] - 2026-02-19

### Fixed
- **Tab proliferation (actual fix)**: `createAppleScript()` in TerminalUtilities.swift still contained `click menu item "New Tab"` for every Warp command, causing a new tab per tool call. Removed the new-tab logic so regular commands (`execute_command`, `execute_with_auto_retrieve`, `execute_pipeline`, etc.) reuse the active Warp tab. Only `open_terminal_tab` creates new tabs.
- **Double-tab on open_terminal_tab**: The initial `cd` command after opening a new tab was routed through `createAppleScript()` which opened yet another tab. Changed to use `keystrokeSendToCurrentTab()` instead.

## [5.0.1] - 2026-02-19

### Added
- **Session cleanup**: `cleanup_sessions` tool (tool #31) to remove stale terminal sessions after a configurable inactivity period and optionally close their associated Warp tabs.
- Session manager tracks `lastActivity` timestamps for stale session detection

## [5.0.0] - 2026-02-18

### Added

- **Clipboard Bridge** (`copy_to_clipboard`, `read_from_clipboard`): Read and write the macOS clipboard directly from Claude Desktop via NSPasteboard.

- **macOS Notifications** (`set_notification_preference`): Native macOS notifications when long-running commands complete. Configurable sound, success/failure filtering, and minimum duration threshold.

- **Environment Intelligence** (`get_environment_context`): Single-call probe of terminal context including current directory, git branch and status, active Python venv, Node version, Docker containers, Conda environment, and NVM version.

- **Output Parsers** (`execute_and_parse`): Structured JSON parsing for common command outputs. Supported parsers: `git status`, `git log`, `docker ps`, `npm test`/`pytest`, `ls -la`, plus generic JSON passthrough.

- **Environment Snapshots** (`capture_environment`, `diff_environment`): Capture named snapshots of all environment variables and diff any two snapshots to see additions, removals, and changes.

- **Workspace Profiles** (`save_workspace_profile`, `load_workspace_profile`, `list_workspace_profiles`, `delete_workspace_profile`): Save and restore project contexts including working directory, environment variables, default commands, and terminal preference. Stored at `~/.claude-command-runner/profiles.json`.

- **Multi-Terminal Sessions** (`open_terminal_tab`, `send_to_session`, `list_sessions`, `close_session`): Orchestrate multiple named terminal tabs. Open tabs, send commands to specific sessions, and manage the session lifecycle.

- **Interactive Command Detection**: Smart detection of interactive commands (ssh, vim, nano, python REPL, psql, etc.) with graceful handling. Instead of timing out, returns a warning and directs the user to interact directly in the terminal. Configurable via `interactiveDetection.customPatterns`.

- **File System Watchers** (`add_file_watch`, `remove_file_watch`, `list_file_watches`): Watch directories for file changes using FSEvents. Trigger commands automatically with configurable glob patterns and debounce. Max 5 concurrent watchers with auto-expiry.

- **SSH Remote Execution** (`ssh_execute`, `save_ssh_profile`, `list_ssh_profiles`, `delete_ssh_profile`): Run commands on remote hosts via SSH key authentication. Connection profiles stored at `~/.claude-command-runner/ssh_profiles.json`. Key-only auth by default for security.

### Changed
- Version bumped from 4.1.0 to 5.0.0
- Tool count expanded from 12 to 30
- Configuration extended with 5 new sections: `notifications`, `workspace`, `fileWatching`, `ssh`, `interactiveDetection`
- Security blocked-command checks now also apply to SSH remote commands

### Technical
- 8 new source files: `ClipboardBridge.swift`, `EnvironmentContext.swift`, `OutputParsers.swift`, `EnvironmentSnapshot.swift`, `WorkspaceProfiles.swift`, `TerminalSessions.swift`, `FileWatcher.swift`, `SSHExecution.swift`
- Modified: `CommandHandlers.swift` (interactive detection), `NotificationSupport.swift` (real macOS notifications), `Configuration.swift` (new config sections + validation), `ClaudeCommandRunner.swift` (tool registration)
- All new features use Foundation/AppKit — no new external dependencies
- Actor-based concurrency for thread-safe state management (EnvironmentStore, FileWatcher, SessionManager, SSHProfileStore)

## [4.1.0] - 2025-12-30

### Added
- **Command History** (`list_recent_commands`): View recent command history from SQLite database
  - Filter by status: `all`, `success`, `failed`
  - Search within command text
  - Configurable limit (1-50 commands)
  - Shows exit codes, duration, timestamps, and working directories

- **Health Check** (`self_check`): Comprehensive system diagnostics
  - Configuration validation
  - Database integrity check with statistics
  - Terminal (Warp) availability detection
  - Temp directory writability verification
  - Recent error rate analysis
  - Returns overall health status with warnings

- **Auto Temp Cleanup**: Automatic cleanup of orphaned temp files on startup
  - Removes `claude_output_*`, `claude_stream_*`, `claude_script_*` files older than 24 hours
  - Prevents `/tmp` pollution from interrupted sessions
  - Logs cleanup statistics

### Technical
- New file: `HealthAndHistory.swift` containing all v4.1 features
- Cleanup runs non-blocking on MCP server startup
- Leverages existing SQLite command history infrastructure

## [4.0.1] - 2025-12-30

### Fixed
- **Critical: Streaming Exit Code Bug** - Fixed `execute_with_streaming` incorrectly reporting exit code 0 for failed commands
  - The `$?` was capturing the `while` loop's exit code (always 0) instead of the actual command's exit code
  - Now uses `set -o pipefail` and `${PIPESTATUS[0]}` to correctly capture the original command's exit status
  - Credit: Discovered during Warp AI code audit

### Technical
- Updated bash wrapper script to use `pipefail` and `PIPESTATUS` array for proper pipeline exit code propagation

## [4.0.0] - 2025-12-01

### Added
- **Command Pipelines** (`execute_pipeline`): Chain multiple commands with conditional logic
  - `on_fail: stop` - Stop pipeline on failure (default)
  - `on_fail: continue` - Continue to next step regardless of failure
  - `on_fail: warn` - Log warning but continue
  - Named steps for clear output
  - Detailed execution summary with timing

- **Output Streaming** (`execute_with_streaming`): Real-time output for long-running commands
  - Configurable update interval (default: 2 seconds)
  - Maximum duration limit (default: 120 seconds)
  - Progressive output display
  - Ideal for builds that previously appeared to "hang"

- **Command Templates**: Save and reuse command patterns
  - `save_template` - Store templates with `{{variable}}` placeholders
  - `run_template` - Execute templates with variable substitution
  - `list_templates` - View all saved templates
  - Category organization
  - Templates stored in `~/.claude-command-runner/templates.json`

### Changed
- Version bumped to 4.0.0
- Moved disabled WarpCode integration out of Sources to fix build

### Technical
- New file: `PipelineAndStreaming.swift` containing all v4.0 features
- Fixed MCP Value type handling (uses string parsing for integers)
- Maintained backward compatibility with all v3.0 tools

## [3.0.1] - 2025-06-30

### Fixed
- Added database logging diagnostics to identify command save failures
- Enhanced error reporting for SQLite operations
- Improved database connection verification

### Known Issues
- Database command logging not functioning - investigation ongoing
- Command suggestions returning empty results

## [2.2.0] - 2025-06-29

### Added
- **Standard Warp Terminal Support**: Full compatibility with production Warp Terminal (not just Preview)
- **Terminal Auto-Detection**: Automatically detects and configures available terminals
- **Configuration System**: Comprehensive config file at `~/.claude-command-runner/config.json`
- **Config Manager Tool**: CLI utility for managing configuration

- **Installation Script**: Automated setup with `install.sh`
- **Terminal Fallback System**: Automatic fallback to available terminals
- **Warp Database Integration**: Direct access to Warp's SQLite command history
- **Pending Commands**: Check for commands completed while Claude was idle
- **Security Configuration**: Customizable blocked commands and patterns
- **Custom Terminal Support**: Add any terminal via configuration
- **Command Validation**: Pre-execution security checks

### Changed
- Refactored terminal detection to use bundle identifiers
- Improved error messages when terminal not found
- Modularized command handlers for better maintainability
- Enhanced AppleScript generation per terminal type
- Updated directory structure for better organization

### Fixed
- Terminal detection now works with standard Warp installations
- Better handling of missing terminals
- Improved error recovery in command execution

### Security
- Added configurable command blocking patterns
- Implemented maximum command length limits
- Added dangerous command confirmation requirements

## [2.1.0] - 2025-06-14

### Added
- **Auto-Retrieve Mode**: `execute_with_auto_retrieve` tool for automatic output capture
- **Two-Way Communication**: Seamless command execution and output retrieval
- **Suggest Command Tool**: AI-powered command suggestions
- **Preview Command**: Preview commands before execution
- **Verbose Logging**: Detailed debugging information

### Changed
- Improved MCP protocol implementation
- Enhanced error handling and recovery
- Better output formatting for readability

### Fixed
- Output capture timing issues
- JSON parsing errors in edge cases
- Terminal focus handling

## [2.0.0] - 2025-06-07

### Added
- Complete rewrite in Swift
- MCP server implementation
- JSON-RPC communication
- Warp Preview integration
- Security approval system

### Changed
- Migrated from Python to Swift
- New architecture for better performance
- Improved security model

### Removed
- Python dependencies
- Direct terminal control

## [1.0.0] - 2025-05-15

### Added
- Initial release
- Basic command execution
- Output capture
- Warp terminal support

---

## Versioning Guide

- **Major version (X.0.0)**: Breaking changes or complete rewrites
- **Minor version (0.X.0)**: New features, backward compatible
- **Patch version (0.0.X)**: Bug fixes and minor improvements

## Upgrade Guide

### From 4.x to 5.0.0
- No breaking changes — all existing tools work identically
- Rebuild with `swift build -c release`
- Restart Claude Desktop to load updated MCP
- New config sections are auto-populated with sensible defaults on first run
- New data files (`profiles.json`, `ssh_profiles.json`) are created on first use

### From 4.0.0 to 4.0.1
- No breaking changes - patch fix only
- Rebuild with `swift build -c release`
- Restart Claude Desktop to load updated MCP

### From 2.1 to 2.2
1. Update configuration path from Warp Preview to standard Warp
2. Run `./install.sh` to set up new configuration system
3. Review and customize `~/.claude-command-runner/config.json`
4. Update Claude Desktop configuration if needed

### From 2.0 to 2.1
- No breaking changes
- Simply rebuild and restart Claude Desktop

### From 1.x to 2.x
- Complete reinstallation required
- New Swift-based implementation
- Update Claude Desktop MCP configuration
