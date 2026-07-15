#!/bin/bash
# Script to compile and run TorMenu in the background

# Work directory
cd "$(dirname "$0")"

# Kill existing instance if running
killall TorMenu 2>/dev/null

# Recompile to apply changes
swiftc TorMenu.swift -o TorMenu

# Run in background without blocking the terminal
nohup ./TorMenu >/dev/null 2>&1 &

echo "[+] TorMenu started successfully!"
