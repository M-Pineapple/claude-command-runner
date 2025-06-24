#!/bin/bash

# Quick test script to verify the server is working

echo "Claude Command Runner - Quick Test"
echo "================================="
echo ""

# Check if the executable exists
if [ ! -f ".build/release/claude-command-runner" ]; then
    echo "❌ Error: Executable not found. Please run ./build.sh first"
    exit 1
fi

echo "✅ Executable found"

# Test help command
echo ""
echo "Testing help command..."
.build/release/claude-command-runner --help

echo ""
echo "✅ All basic tests passed!"
echo ""
echo "Next steps:"
echo "1. Run './test_server.sh' in one terminal to start the server"
echo "2. Run './examples/test_client.py' in another terminal to test the command receiver"
echo "3. Configure Warp Terminal with the MCP server"
