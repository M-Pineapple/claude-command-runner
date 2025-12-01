#!/bin/bash

echo "🔍 Comparing MCP Configurations: Claude vs Msty"
echo "=============================================="
echo ""

echo "1. Claude Desktop MCP Config Location:"
CLAUDE_CONFIG="$HOME/.claude_desktop_config.json"
if [ -f "$CLAUDE_CONFIG" ]; then
    echo "   ✅ Found: $CLAUDE_CONFIG"
    echo "   📄 Claude Command Runner section:"
    if command -v jq >/dev/null 2>&1; then
        jq '.mcpServers."claude-command-runner"' "$CLAUDE_CONFIG" 2>/dev/null || echo "   No claude-command-runner found in config"
    else
        grep -A 10 -B 2 "claude-command-runner" "$CLAUDE_CONFIG" || echo "   No claude-command-runner found"
    fi
else
    echo "   ❌ Not found: $CLAUDE_CONFIG"
fi

echo ""
echo "2. Process Comparison:"
echo "   Current MCP processes:"
ps aux | grep claude-command-runner | grep -v grep || echo "   No MCP processes running"

echo ""
echo "3. Key Diagnostic Questions:"
echo "   When you use the MCP with me (Claude Desktop):"
echo "   • Do commands appear in Warp terminal?"
echo "   • Do they execute when you press Enter?"
echo ""
echo "   When Grok uses the MCP in Msty:"
echo "   • Do commands appear in Warp terminal at all?"
echo "   • Or does nothing show up in Warp?"
echo ""

echo "4. Testing Theory - Process Owner:"
echo "   Current user: $(whoami)"
echo "   Terminal parent process: $(ps -o ppid= -p $$)"
echo "   This might explain permission differences!"

echo ""
echo "💡 HYPOTHESIS:"
echo "If the same JSON config works with Claude but not Msty,"
echo "the issue is likely:"
echo "• Different process permissions/ownership"
echo "• Different MCP invocation method"
echo "• Different error handling between AI clients"
echo "• Msty may not be starting the MCP correctly"

echo ""
echo "🧪 NEXT TEST:"
echo "Try manually starting the MCP the way Msty would:"
echo "cd '/Users/rogers/GitHub/MCP Directory/claude-command-runner'"
echo "./.build/release/claude-command-runner"
echo ""
echo "Then test with Msty to see if it connects to the running instance."
