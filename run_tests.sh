#!/bin/bash

# Claude Command Runner v3.0 - Automated Test Suite
# This script runs basic automated tests for the main features

set -e

echo "🧪 Claude Command Runner v3.0 Test Suite"
echo "========================================"
echo ""

# Colors for output
GREEN='\033[0;32m'
RED='\033[0;31m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

# Test counter
TESTS_PASSED=0
TESTS_FAILED=0

# Function to run a test
run_test() {
    local test_name="$1"
    local test_command="$2"
    local expected_result="$3"
    
    echo -n "Testing: $test_name... "
    
    if eval "$test_command"; then
        echo -e "${GREEN}✓ PASSED${NC}"
        ((TESTS_PASSED++))
    else
        echo -e "${RED}✗ FAILED${NC}"
        echo "  Command: $test_command"
        echo "  Expected: $expected_result"
        ((TESTS_FAILED++))
    fi
}

# Function to check if file exists
check_file() {
    local file="$1"
    local description="$2"
    
    echo -n "Checking: $description... "
    
    if [ -f "$file" ]; then
        echo -e "${GREEN}✓ EXISTS${NC}"
        ((TESTS_PASSED++))
    else
        echo -e "${RED}✗ MISSING${NC}"
        ((TESTS_FAILED++))
    fi
}

# Function to check if directory exists
check_dir() {
    local dir="$1"
    local description="$2"
    
    echo -n "Checking: $description... "
    
    if [ -d "$dir" ]; then
        echo -e "${GREEN}✓ EXISTS${NC}"
        ((TESTS_PASSED++))
    else
        echo -e "${RED}✗ MISSING${NC}"
        ((TESTS_FAILED++))
    fi
}

echo "1. Build Tests"
echo "--------------"

# Test 1: Build the project
run_test "Swift build" "swift build --quiet" "Build should complete successfully"

echo ""
echo "2. Installation Tests"
echo "--------------------"

# Test 2: Check configuration directory
check_dir "$HOME/.claude-command-runner" "Configuration directory"

# Test 3: Check configuration file
check_file "$HOME/.claude-command-runner/config.json" "Configuration file"

# Test 4: Check database file
check_file "$HOME/.claude-command-runner/claude_commands.db" "SQLite database"

echo ""
echo "3. Binary Tests"
echo "---------------"

# Test 5: Check if binary exists
BINARY_PATH="$HOME/.claude-command-runner/claude-command-runner"
check_file "$BINARY_PATH" "Executable binary"

# Test 6: Test binary execution
if [ -f "$BINARY_PATH" ]; then
    run_test "Binary execution" "$BINARY_PATH --help 2>&1 | grep -q 'MCP server bridging Claude Desktop and Warp Terminal'" "Help text should display"
fi

echo ""
echo "4. Configuration Tests"
echo "---------------------"

# Test 7: Validate configuration
if [ -f "$HOME/.claude-command-runner/config.json" ]; then
    run_test "Configuration validation" "cat $HOME/.claude-command-runner/config.json | python3 -m json.tool > /dev/null" "Valid JSON configuration"
fi

echo ""
echo "5. Database Tests"
echo "-----------------"

# Test 8: Database accessibility
if [ -f "$HOME/.claude-command-runner/claude_commands.db" ]; then
    run_test "Database readable" "sqlite3 $HOME/.claude-command-runner/claude_commands.db '.tables' | grep -q 'commands'" "Commands table exists"
fi

echo ""
echo "6. Terminal Detection Tests"
echo "--------------------------"

# Test 9: Check for available terminals
echo -n "Detecting installed terminals... "
TERMINALS_FOUND=""

if [ -d "/Applications/Warp.app" ]; then
    TERMINALS_FOUND="$TERMINALS_FOUND Warp"
fi

if [ -d "/Applications/iTerm.app" ]; then
    TERMINALS_FOUND="$TERMINALS_FOUND iTerm2"
fi

if [ -d "/System/Applications/Utilities/Terminal.app" ]; then
    TERMINALS_FOUND="$TERMINALS_FOUND Terminal.app"
fi

if [ -d "/Applications/Alacritty.app" ]; then
    TERMINALS_FOUND="$TERMINALS_FOUND Alacritty"
fi

if [ -n "$TERMINALS_FOUND" ]; then
    echo -e "${GREEN}✓ Found:$TERMINALS_FOUND${NC}"
    ((TESTS_PASSED++))
else
    echo -e "${RED}✗ No supported terminals found${NC}"
    ((TESTS_FAILED++))
fi

echo ""
echo "7. Source Code Tests"
echo "-------------------"

# Test 10: Check for v3.0 files
check_file "Sources/ClaudeCommandRunner/Database/DatabaseManager.swift" "DatabaseManager (v3.0)"
check_file "Sources/ClaudeCommandRunner/CommandSuggestionEngine.swift" "CommandSuggestionEngine (v3.0)"
check_file "Sources/ClaudeCommandRunner/TerminalConfig.swift" "TerminalConfig (v2.2)"
check_file "Sources/ClaudeCommandRunner/Configuration.swift" "Configuration system"

echo ""
echo "8. Feature Tests"
echo "----------------"

# Test 11: Check for auto-retrieve in source
run_test "Auto-retrieve feature" "grep -q 'handleExecuteWithAutoRetrieve' Sources/ClaudeCommandRunner/CommandHandlers.swift" "Auto-retrieve implemented"

# Test 12: Check for multi-terminal support
run_test "Multi-terminal support" "grep -q 'enum TerminalType' Sources/ClaudeCommandRunner/TerminalConfig.swift" "Terminal types defined"

# Test 13: Check for SQLite integration
run_test "SQLite integration" "grep -q 'import SQLite3' Sources/ClaudeCommandRunner/Database/DatabaseManager.swift" "SQLite3 imported"

echo ""
echo "========================================"
echo "Test Summary"
echo "========================================"
echo -e "Tests Passed: ${GREEN}$TESTS_PASSED${NC}"
echo -e "Tests Failed: ${RED}$TESTS_FAILED${NC}"
echo ""

if [ $TESTS_FAILED -eq 0 ]; then
    echo -e "${GREEN}✅ All tests passed! Claude Command Runner v3.0 is ready for manual testing.${NC}"
    exit 0
else
    echo -e "${YELLOW}⚠️  Some tests failed. Please check the output above for details.${NC}"
    exit 1
fi