#!/bin/bash

# Quick fix script for Claude Command Runner MCP - Warp Terminal Issue
# This fixes the missing Enter key press that prevents commands from executing

echo "🔧 Fixing Claude Command Runner MCP for Warp Terminal..."

# Backup original file
ORIGINAL_FILE="/Users/rogers/GitHub/MCP Directory/claude-command-runner/Sources/ClaudeCommandRunner/TerminalUtilities.swift"
BACKUP_FILE="${ORIGINAL_FILE}.backup.$(date +%Y%m%d_%H%M%S)"

echo "📁 Creating backup: $BACKUP_FILE"
cp "$ORIGINAL_FILE" "$BACKUP_FILE"

# Apply the fix using sed
echo "⚡ Applying fix..."

# Fix for Warp: Add Enter key press and improve timing
sed -i '' '/case \.warp, \.warpPreview:/,/end tell/ {
    s/delay 0\.5/delay 1.0/
    /keystroke "\\$(command)"/a\
            delay 0.2\
            keystroke return
}' "$ORIGINAL_FILE"

# Fix for Alacritty: Add Enter key press
sed -i '' '/case \.alacritty:/,/end tell/ {
    s/delay 0\.5/delay 1.0/
    /keystroke "\\$(command)"/a\
            delay 0.2\
            keystroke return
}' "$ORIGINAL_FILE"

echo "✅ Fix applied successfully!"
echo ""
echo "🔄 Changes made:"
echo "  - Added 'keystroke return' after command input for Warp and Alacritty"
echo "  - Increased delay from 0.5s to 1.0s for better reliability"
echo "  - Added 0.2s delay before pressing Enter"
echo ""
echo "📝 To rebuild the MCP:"
echo "  cd '$(/Users/rogers/GitHub/MCP Directory/claude-command-runner)'"
echo "  swift build -c release"
echo ""
echo "🔧 Or to revert changes:"
echo "  cp '$BACKUP_FILE' '$ORIGINAL_FILE'"
