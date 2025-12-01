#!/bin/bash

echo "🔍 REAL ISSUE DIAGNOSIS: Commands Not Appearing in Warp"
echo "======================================================="
echo ""

echo "1. Testing AppleScript Permissions..."
echo "   Trying to send a test keystroke to Warp:"

# Test if we can actually control Warp via AppleScript
osascript -e '
tell application "Warp" to activate
delay 1
tell application "System Events"
    keystroke "echo APPLESCRIPT_TEST_SUCCESS"
    delay 0.2
    keystroke return
end tell
' 2>&1

if [ $? -eq 0 ]; then
    echo "   ✅ AppleScript can control Warp"
else
    echo "   ❌ AppleScript CANNOT control Warp"
    echo "   💡 This is likely the root cause!"
    echo ""
    echo "🔧 PERMISSION FIXES NEEDED:"
    echo "   1. System Preferences > Security & Privacy > Privacy > Accessibility"
    echo "   2. Add and enable: Terminal.app, osascript, Script Editor"
    echo "   3. Add and enable: Your MCP binary at .build/release/claude-command-runner"
    echo "   4. Restart terminal and try again"
fi

echo ""
echo "2. Testing Warp Detection..."
WARP_RUNNING=$(ps aux | grep -v grep | grep Warp | wc -l)
if [ $WARP_RUNNING -gt 0 ]; then
    echo "   ✅ Warp is running ($WARP_RUNNING processes)"
else
    echo "   ❌ Warp is NOT running"
    echo "   💡 Start Warp first!"
fi

echo ""
echo "3. Testing MCP Server Status..."
MCP_RUNNING=$(ps aux | grep -v grep | grep claude-command-runner | wc -l)
if [ $MCP_RUNNING -gt 0 ]; then
    echo "   ✅ MCP server is running"
    ps aux | grep claude-command-runner | grep -v grep
else
    echo "   ❌ MCP server is NOT running"
    echo "   💡 Start MCP server first!"
fi

echo ""
echo "4. Testing Port 9876..."
if lsof -i :9876 >/dev/null 2>&1; then
    echo "   ✅ Port 9876 is in use"
    lsof -i :9876
else
    echo "   ❌ Port 9876 is NOT in use"
    echo "   💡 MCP may not be listening"
fi

echo ""
echo "5. Manual AppleScript Test..."
echo "   Run this manually to test:"
echo '   osascript -e "tell application \"Warp\" to activate" -e "delay 1" -e "tell application \"System Events\" to keystroke \"echo MANUAL_TEST\""'

echo ""
echo "🎯 ROOT CAUSE ANALYSIS:"
echo "If AppleScript test failed above, the issue is:"
echo "  • macOS security blocking AppleScript automation"
echo "  • Missing accessibility permissions" 
echo "  • Warp not responding to AppleScript commands"
echo ""
echo "This explains why Grok claims success but nothing appears in Warp!"
