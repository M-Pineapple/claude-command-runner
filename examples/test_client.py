#!/usr/bin/env python3
"""
Example client for testing Claude Command Runner MCP Server
This demonstrates how Claude Desktop could interact with the command receiver
"""

import json
import socket
import sys

def send_command(host='127.0.0.1', port=9876, command_data=None):
    """Send a command to the Claude Command Runner server"""
    try:
        # Create a socket connection
        with socket.socket(socket.AF_INET, socket.SOCK_STREAM) as s:
            s.connect((host, port))
            
            # Send the command
            message = json.dumps(command_data) + '\n'
            s.sendall(message.encode())
            
            # Receive the response
            response = s.recv(4096).decode()
            return json.loads(response.strip())
            
    except Exception as e:
        return {"error": str(e)}

def main():
    """Example usage of the Claude Command Runner client"""
    
    print("Claude Command Runner - Example Client")
    print("=====================================\n")
    
    # Test 1: Ping the server
    print("1. Testing connection...")
    response = send_command(command_data={"type": "ping"})
    print(f"Response: {json.dumps(response, indent=2)}\n")
    
    # Test 2: Suggest a command
    print("2. Requesting command suggestion...")
    response = send_command(command_data={
        "type": "suggest",
        "query": "How do I list all files modified in the last 24 hours?"
    })
    print(f"Response: {json.dumps(response, indent=2)}\n")
    
    # Test 3: Execute a simple command
    print("3. Executing a test command...")
    response = send_command(command_data={
        "type": "execute",
        "command": "echo 'Hello from Claude Command Runner!'",
        "working_directory": None
    })
    print(f"Response: {json.dumps(response, indent=2)}\n")
    
    # Interactive mode
    print("Interactive Mode - Enter commands (type 'quit' to exit)")
    print("Format: suggest <query> | execute <command> | ping")
    print("-" * 50)
    
    while True:
        try:
            user_input = input("> ").strip()
            
            if user_input.lower() == 'quit':
                break
                
            if user_input.lower() == 'ping':
                response = send_command(command_data={"type": "ping"})
                
            elif user_input.startswith('suggest '):
                query = user_input[8:]
                response = send_command(command_data={
                    "type": "suggest",
                    "query": query
                })
                
            elif user_input.startswith('execute '):
                command = user_input[8:]
                response = send_command(command_data={
                    "type": "execute",
                    "command": command
                })
            else:
                print("Invalid command format. Use: suggest <query> | execute <command> | ping")
                continue
                
            print(f"Response: {json.dumps(response, indent=2)}")
            
        except KeyboardInterrupt:
            print("\nExiting...")
            break
        except Exception as e:
            print(f"Error: {e}")

if __name__ == "__main__":
    main()
