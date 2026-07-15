#!/bin/bash
# Build and install script for TorMenu.app

# Target directories
APP_DIR="TorMenu.app"
CONTENTS_DIR="$APP_DIR/Contents"
MACOS_DIR="$CONTENTS_DIR/MacOS"

# Clean previous build
rm -rf "$APP_DIR"

# Create directories
mkdir -p "$MACOS_DIR"

# Compile TorMenu
echo "[*] Compiling TorMenu..."
swiftc -O TorMenu.swift -o "$MACOS_DIR/TorMenu"

# Create Info.plist
echo "[*] Creating Info.plist..."
cat <<EOF > "$CONTENTS_DIR/Info.plist"
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
    <key>CFBundleExecutable</key>
    <string>TorMenu</string>
    <key>CFBundleIdentifier</key>
    <string>com.bexprod.tormenu</string>
    <key>CFBundleName</key>
    <string>TorMenu</string>
    <key>CFBundlePackageType</key>
    <string>APPL</string>
    <key>CFBundleShortVersionString</key>
    <string>1.0</string>
    <key>LSMinimumSystemVersion</key>
    <string>11.0</string>
    <key>LSUIElement</key>
    <true/>
    <key>NSPrincipalClass</key>
    <string>NSApplication</string>
</dict>
</plist>
EOF

echo "[+] TorMenu.app built successfully!"

# Install to /Applications
echo "[*] Installing to /Applications..."
rm -rf "/Applications/TorMenu.app"
cp -R "$APP_DIR" "/Applications/"
rm -rf "$APP_DIR"

# Configure LaunchAgent
echo "[*] Configuring LaunchAgent..."
PLIST_PATH="$HOME/Library/LaunchAgents/com.bexprod.tormenu.plist"
launchctl unload "$PLIST_PATH" 2>/dev/null
killall TorMenu 2>/dev/null

cat <<EOF > "$PLIST_PATH"
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
    <key>Label</key>
    <string>com.bexprod.tormenu</string>
    <key>ProgramArguments</key>
    <array>
        <string>/Applications/TorMenu.app/Contents/MacOS/TorMenu</string>
    </array>
    <key>RunAtLoad</key>
    <true/>
    <key>KeepAlive</key>
    <false/>
</dict>
</plist>
EOF

launchctl load "$PLIST_PATH"
launchctl start com.bexprod.tormenu

echo "[+] TorMenu.app is now installed in /Applications and set to launch automatically at login!"
