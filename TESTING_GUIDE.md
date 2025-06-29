# Claude Command Runner v3.0 Testing Guide

## Overview
This document outlines comprehensive testing procedures for all features implemented in Claude Command Runner v3.0, including verification steps and remaining items from the development plan.

---

## 1. Core Functionality Tests

### 1.1 Basic Command Execution
- [ ] **Test simple command execution**
  ```bash
  # In Claude Desktop:
  suggest_command: "list files in current directory"
  execute_command: "ls -la"
  ```
  - Verify: Command appears in Warp Terminal
  - Verify: User can press Enter to execute
  - Verify: Command ID is generated

- [ ] **Test command with working directory**
  ```bash
  execute_command: "pwd" with working_directory: "/tmp"
  ```
  - Verify: Command executes in specified directory

### 1.2 Output Retrieval
- [ ] **Test manual output retrieval**
  ```bash
  execute_command: "echo 'Hello World'"
  # After execution in terminal:
  get_command_output: "last"
  ```
  - Verify: Output is correctly captured
  - Verify: Exit code is shown
  - Verify: Timestamp is accurate

- [ ] **Test output retrieval by command ID**
  ```bash
  execute_command: "date"
  # Note the command ID
  get_command_output: "[COMMAND_ID]"
  ```
  - Verify: Specific command output is retrieved

### 1.3 Auto-Retrieve Mode ⭐ NEW
- [ ] **Test automatic output capture**
  ```bash
  execute_with_auto_retrieve: "ls -la"
  ```
  - Verify: Command executes
  - Verify: Output is automatically captured within 60 seconds
  - Verify: Combined result shows both execution and output

- [ ] **Test auto-retrieve with long-running commands**
  ```bash
  execute_with_auto_retrieve: "sleep 5 && echo 'Done'"
  ```
  - Verify: Wait indication during execution
  - Verify: Output captured after completion

---

## 2. Terminal Support Tests ⭐ NEW

### 2.1 Multi-Terminal Detection
- [ ] **Test with Warp Terminal**
  - Verify: Commands sent to standard Warp (not just Preview)
  - Verify: Proper error if Warp not installed

- [ ] **Test with iTerm2**
  - Install iTerm2 if not present
  - Verify: Commands sent correctly to iTerm2
  - Verify: AppleScript integration works

- [ ] **Test with Terminal.app**
  - Verify: Commands sent to macOS Terminal
  - Verify: New tab/window handling

- [ ] **Test with Alacritty**
  - Install Alacritty if testing this
  - Verify: Keyboard event simulation works

### 2.2 Terminal Fallback
- [ ] **Test fallback mechanism**
  - Set preferred terminal to non-existent app
  - Verify: Falls back to available terminal
  - Verify: Appropriate warning message

---

## 3. Database Features Tests ⭐ NEW

### 3.1 Command History Storage
- [ ] **Test automatic history recording**
  ```bash
  execute_command: "echo 'test history'"
  # Check database at ~/.claude-command-runner/claude_commands.db
  ```
  - Verify: Command stored in database
  - Verify: Metadata recorded (timestamp, exit code, duration)

- [ ] **Test history retrieval**
  - Execute multiple commands
  - Verify: Can query history by date
  - Verify: Can search by command content

### 3.2 Project Detection
- [ ] **Test Git project detection**
  ```bash
  # Execute command in a git repository
  execute_command: "git status" with working_directory: "/path/to/git/repo"
  ```
  - Verify: Project name detected from git
  - Verify: Project associated with command in database

- [ ] **Test non-git project detection**
  - Execute commands in various directories
  - Verify: Project detection from directory name

### 3.3 Analytics
- [ ] **Test command frequency tracking**
  - Execute same command multiple times
  - Verify: Usage count increases
  - Verify: Last used timestamp updates

- [ ] **Test success rate tracking**
  - Execute commands with different exit codes
  - Verify: Success/failure rates calculated correctly

---

## 4. Smart Suggestions Tests ⭐ NEW

### 4.1 Context-Aware Suggestions
- [ ] **Test Git context suggestions**
  ```bash
  suggest_command: "show git changes"
  ```
  - Verify: Suggests appropriate git commands
  - Verify: Multiple relevant options provided

- [ ] **Test Swift/Xcode context**
  ```bash
  suggest_command: "build ios app"
  ```
  - Verify: Suggests xcodebuild commands
  - Verify: Detects iOS development context

- [ ] **Test general command transformation**
  ```bash
  suggest_command: "find large files"
  ```
  - Verify: Transforms to appropriate find command
  - Verify: Includes size parameters

### 4.2 History-Based Suggestions
- [ ] **Test learning from history**
  - Execute several similar commands
  - Request suggestions for similar task
  - Verify: Previously used commands appear in suggestions

### 4.3 Template Suggestions
- [ ] **Test template matching**
  - Create command templates in database
  - Request suggestions matching template pattern
  - Verify: Templates offered as suggestions

---

## 5. Configuration System Tests ⭐ NEW

### 5.1 Configuration File
- [ ] **Test configuration loading**
  - Check ~/.claude-command-runner/config.json
  - Verify: Default configuration created if missing
  - Verify: Custom settings respected

- [ ] **Test configuration validation**
  - Modify config with invalid values
  - Verify: Validation errors reported
  - Verify: Fallback to defaults

### 5.2 Security Settings
- [ ] **Test blocked commands**
  - Add commands to blocklist in config
  - Attempt to execute blocked command
  - Verify: Command rejected with appropriate message

- [ ] **Test security patterns**
  - Configure dangerous patterns (e.g., "rm -rf")
  - Verify: Pattern matching prevents execution

### 5.3 Output Settings
- [ ] **Test capture timeout**
  - Configure custom timeout
  - Execute long-running command
  - Verify: Timeout respected

- [ ] **Test output size limits**
  - Configure max output size
  - Execute command with large output
  - Verify: Output truncated appropriately

---

## 6. Error Handling Tests

### 6.1 Command Failures
- [ ] **Test invalid command execution**
  ```bash
  execute_command: "nonexistentcommand"
  ```
  - Verify: Error captured
  - Verify: Appropriate error message

### 6.2 Database Errors
- [ ] **Test database corruption recovery**
  - Corrupt database file
  - Verify: Graceful degradation
  - Verify: Error logged

### 6.3 Terminal Errors
- [ ] **Test terminal not responding**
  - Block terminal temporarily
  - Verify: Timeout handling
  - Verify: Error message to user

---

## 7. Integration Tests

### 7.1 ConfigManager Tool
- [ ] **Test configuration management**
  ```bash
  ./ConfigManager --show
  ./ConfigManager --validate
  ./ConfigManager --set terminal.preferred "iTerm2"
  ```
  - Verify: Each command works correctly
  - Verify: Changes reflected in config file

### 7.2 Installation Script
- [ ] **Test fresh installation**
  ```bash
  ./install.sh
  ```
  - Verify: All dependencies checked
  - Verify: Configuration initialized
  - Verify: Proper permissions set

### 7.3 Warp Database Integration
- [ ] **Test Warp history import**
  - If Warp installed, verify history reading
  - Verify: No interference with Warp operation

---

## 8. Performance Tests

### 8.1 Database Performance
- [ ] **Test with large history**
  - Generate 10,000+ command entries
  - Verify: Suggestions still fast (<100ms)
  - Verify: No UI blocking

### 8.2 Memory Usage
- [ ] **Test memory consumption**
  - Run for extended period
  - Monitor memory usage
  - Verify: No memory leaks

---

## 9. Remaining Features to Implement

Based on the development plan, the following features are **NOT YET IMPLEMENTED**:

### 9.1 Advanced Features (Phase 2)
- [ ] **Plugin System**
  - Plugin API design
  - Plugin loading mechanism
  - Example plugins

- [ ] **Command Chaining**
  - Pipe support between commands
  - Sequential execution
  - Conditional execution

- [ ] **Environment Profiles**
  - Multiple environment configurations
  - Quick switching between profiles
  - Environment variable management

### 9.2 Future Enhancements
- [ ] **Web Dashboard**
  - Command history visualization
  - Analytics dashboard
  - Remote command execution

- [ ] **Team Sharing**
  - Shared command templates
  - Team analytics
  - Access control

- [ ] **AI-Powered Features**
  - Command explanation
  - Error diagnosis
  - Automated fixes

- [ ] **Advanced Scheduling**
  - Cron-like scheduling
  - Delayed execution
  - Recurring commands

### 9.3 Additional Terminal Support
- [ ] **Windows Terminal** (for future Windows support)
- [ ] **Kitty Terminal**
- [ ] **Hyper Terminal**

---

## Testing Checklist Summary

### ✅ Implemented & Ready to Test:
1. Basic command execution and output retrieval
2. Auto-retrieve mode
3. Multi-terminal support (Warp, iTerm2, Terminal.app, Alacritty)
4. SQLite database integration
5. Command history with metadata
6. Smart context-aware suggestions
7. Configuration system
8. Security features
9. Project detection
10. Analytics and statistics

### ❌ Not Yet Implemented:
1. Plugin system
2. Command chaining
3. Environment profiles
4. Web dashboard
5. Team sharing features
6. AI-powered enhancements
7. Advanced scheduling
8. Additional terminal support

---

## Test Execution Guide

1. **Setup Test Environment**
   ```bash
   # Build the project
   swift build
   
   # Install
   ./install.sh
   
   # Verify installation
   ~/.claude-command-runner/claude-command-runner --version
   ```

2. **Run Through Each Test Category**
   - Mark each test as it's completed
   - Document any failures or unexpected behavior
   - Note performance metrics where applicable

3. **Report Issues**
   - Create GitHub issues for any bugs found
   - Include reproduction steps
   - Attach relevant logs from ~/.claude-command-runner/logs/

4. **Regression Testing**
   - After fixes, re-run affected test categories
   - Ensure no new issues introduced

---

## Notes for Testers

- Always test with a fresh build after code changes
- Test on different macOS versions if possible
- Test with different terminal configurations
- Consider edge cases (empty commands, special characters, etc.)
- Verify all error messages are user-friendly
- Check that all features work together harmoniously

This testing guide should be updated as new features are implemented or issues are discovered.