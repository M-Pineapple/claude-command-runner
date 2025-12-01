#!/bin/bash

# Diagnostic script to help debug Claude Command Runner MCP issues
# This will test different aspects of the MCP connection

echo "🔍 Claude Command Runner MCP Diagnostics"
echo "========================================"
echo ""

# Check if MCP is running
echo "1. Checking MCP Process..."
if pgrep -f "claude-command-runner" > /dev/null; then
    echo "   ✅ Claude Command Runner MCP is running"
    echo "   📊 Process details:"
    ps aux | grep claude-command-runner | grep -v grep | head -5
else
    echo "   ❌ Claude Command Runner MCP is NOT running"
    echo "   💡 Start it with: cd '/Users/rogers/GitHub/MCP Directory/claude-command-runner' && swift run"
fi
echo ""

# Check port
echo "2. Checking Port 9876..."
if lsof -i :9876 > /dev/null 2>&1; then
    echo "   ✅ Port 9876 is in use"
    echo "   📊 Port details:"
    lsof -i :9876
else
    echo "   ❌ Port 9876 is not in use"
    echo "   💡 The MCP may not be running or using a different port"
fi
echo ""

# Check Warp installation
echo "3. Checking Terminal Applications..."
TERMINALS=("Warp" "WarpPreview" "iTerm" "Terminal" "Alacritty")
for terminal in "${TERMINALS[@]}"; do
    if ls /Applications/ | grep -i "$terminal" > /dev/null 2>&1; then
        echo "   ✅ $terminal is installed"
    else
        echo "   ❌ $terminal is not installed"
    fi
done
echo ""

# Check AppleScript permissions
echo "4. Testing AppleScript Permissions..."
if osascript -e 'tell application "System Events" to keystroke "test"' 2>/dev/null; then
    echo "   ✅ AppleScript has System Events access"
else
    echo "   ❌ AppleScript does NOT have System Events access"
    echo "   💡 Go to System Preferences > Security & Privacy > Privacy > Accessibility"
    echo "       and ensure your terminal app and osascript have permission"
fi
echo ""

# Check recent output files
echo "5. Checking Recent Command Outputs..."
OUTPUT_FILES=$(ls -1t /tmp/claude_output_*.json 2>/dev/null | head -5)
if [ -n "$OUTPUT_FILES" ]; then
    echo "   ✅ Found recent output files:"
    echo "$OUTPUT_FILES" | while read file; do
        if [ -f "$file" ]; then
            COMMAND_ID=$(basename "$file" .json | sed 's/claude_output_//')
            TIMESTAMP=$(stat -f "%Sm" -t "%Y-%m-%d %H:%M:%S" "$file" 2>/dev/null || echo "unknown")
            echo "     📄 $COMMAND_ID (created: $TIMESTAMP)"
        fi
    done
else
    echo "   ⚠️  No recent output files found"
    echo "   💡 Commands may not be executing or completing"
fi
echo ""

# Test a simple command
echo "6. Testing Simple Command Execution..."
echo "   💭 This will test if the MCP can execute a basic command..."

# Create a test script
TEST_SCRIPT="/tmp/claude_mcp_test.sh"
cat > "$TEST_SCRIPT" << 'EOF'
#!/bin/bash
echo "Claude MCP Test: $(date)"
echo "Working directory: $(pwd)"
echo "Environment: macOS $(sw_vers -productVersion)"
exit 0
EOF

chmod +x "$TEST_SCRIPT"

echo "   📝 Created test script: $TEST_SCRIPT"
echo "   💡 Try running this with your MCP: execute_command with 'bash $TEST_SCRIPT'"
echo ""

# Check configuration
echo "7. Checking MCP Configuration..."
CONFIG_DIR="$HOME/Library/Application Support/claude-command-runner"
if [ -d "$CONFIG_DIR" ]; then
    echo "   ✅ Configuration directory exists: $CONFIG_DIR"
    if [ -f "$CONFIG_DIR/config.json" ]; then
        echo "   ✅ Configuration file exists"
        echo "   📄 Configuration preview:"
        head -10 "$CONFIG_DIR/config.json" | sed 's/^/       /'
    else
        echo "   ⚠️  Configuration file not found"
    fi
else
    echo "   ❌ Configuration directory not found"
    echo "   💡 Run: claude-command-runner --init-config"
fi
echo ""

echo "🏁 Diagnostics Complete!"
echo ""
echo "📋 Summary for Msty/Grok Issues:"
echo "   1. The MCP sends commands via AppleScript but doesn't press Enter"
echo "   2. This requires manual intervention in Warp terminal"
echo "   3. The fix is to add 'keystroke return' to the AppleScript"
echo "   4. Run ./fix_warp_issue.sh to apply the fix automatically"
echo ""
echo "🔧 Quick Fix Command:"
echo "   ./fix_warp_issue.sh && cd '/Users/rogers/GitHub/MCP Directory/claude-command-runner' && swift build -c release"
