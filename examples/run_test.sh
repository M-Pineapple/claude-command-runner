#!/bin/bash

# Make the test client executable
chmod +x test_client.py

# Ensure the server is running
echo "Please ensure the Claude Command Runner MCP server is running on port 9876"
echo "You can start it with: swift run claude-command-runner --verbose"
echo ""
echo "Press Enter to continue with the test..."
read

# Run the test client
python3 test_client.py
