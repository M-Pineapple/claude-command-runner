#!/bin/bash

echo "Starting Claude Command Runner in test mode..."
echo "========================================"
echo ""
echo "The server will start and you should see:"
echo "- 'MCP Server started successfully'"
echo "- 'Command receiver listening on port 9876'"
echo ""
echo "Press Ctrl+C to stop the server"
echo ""

./claude-command-runner --verbose --log-level debug
