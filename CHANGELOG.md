# Changelog

All notable changes to Claude Command Runner will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.0.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

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