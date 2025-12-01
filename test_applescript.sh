#!/bin/bash

echo "Testing AppleScript Control of Warp - Manual Test"
echo "================================================"

echo "Test 1: Can we activate Warp?"
osascript -e 'tell application "Warp" to activate' 2>&1
sleep 2

echo "Test 2: Can we send keystrokes via System Events?"  
osascript -e '
tell application "System Events"
    keystroke "echo DIRECT_APPLESCRIPT_TEST"
    delay 0.5
    keystroke return
end tell
' 2>&1

echo "Test 3: Combined Warp + keystroke test"
osascript -e '
tell application "Warp" to activate
delay 1
tell application "System Events"
    keystroke "echo COMBINED_TEST_SUCCESS"
    delay 0.5
    keystroke return
end tell
' 2>&1

echo ""
echo "If you see test output in Warp, AppleScript works."
echo "If nothing appears, we need to fix permissions."
