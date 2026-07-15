import AppKit
import Foundation

// Strong global reference
var strongDelegateReference: AppDelegate?

class AppDelegate: NSObject, NSApplicationDelegate {
    var statusItem: NSStatusItem?
    var myMenu: NSMenu?
    var timer: Timer?
    var currentIP: String = "Waiting..."
    var torVersion: String = "Unknown"
    var torCircuit: String = "None"
    var isFetchingIP: Bool = false
    
    func applicationDidFinishLaunching(_ notification: Notification) {
        // Prevent macOS from suspending the app
        UserDefaults.standard.set(false, forKey: "NSSupportsAutomaticTermination")
        ProcessInfo.processInfo.disableAutomaticTermination("Tor Active Monitoring")
        
        // Status Bar Configuration
        statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
        if let button = statusItem?.button {
            button.title = "⚪"
            button.toolTip = "Tor Status Monitor"
            button.target = self
            button.action = #selector(statusBarButtonClicked(_:))
        }
        
        constructMenu()
        updateStatus()
        
        // Monitor status every 5 seconds
        timer = Timer.scheduledTimer(withTimeInterval: 5.0, repeats: true) { [weak self] _ in
            self?.updateStatus()
        }
    }
    
    func constructMenu() {
        let menu = NSMenu()
        menu.autoenablesItems = false
        
        // Status and IP Section
        let statusItemMenu = NSMenuItem(title: "Status: Checking...", action: nil, keyEquivalent: "")
        statusItemMenu.isEnabled = false
        statusItemMenu.tag = 101
        menu.addItem(statusItemMenu)
        
        let ipItemMenu = NSMenuItem(title: "Tor IP: Waiting...", action: #selector(copyIPToClipboard), keyEquivalent: "c")
        ipItemMenu.target = self
        ipItemMenu.isEnabled = false
        ipItemMenu.toolTip = "Click to copy IP to clipboard"
        ipItemMenu.tag = 102
        menu.addItem(ipItemMenu)
        
        let versionItemMenu = NSMenuItem(title: "Tor Version: Checking...", action: nil, keyEquivalent: "")
        versionItemMenu.isEnabled = false
        versionItemMenu.tag = 103
        menu.addItem(versionItemMenu)
        
        let circuitItemMenu = NSMenuItem(title: "Tor Circuit: Checking...", action: nil, keyEquivalent: "")
        circuitItemMenu.isEnabled = false
        circuitItemMenu.tag = 104
        menu.addItem(circuitItemMenu)
        
        menu.addItem(NSMenuItem.separator())
        
        // Quick Actions
        let identityItem = NSMenuItem(title: "New Identity (Request New IP)", action: #selector(newIdentity), keyEquivalent: "n")
        identityItem.target = self
        identityItem.isEnabled = true
        identityItem.tag = 301
        menu.addItem(identityItem)
        
        let repairItem = NSMenuItem(title: "Repair Tor (Clear Cache)", action: #selector(repairTor), keyEquivalent: "f")
        repairItem.target = self
        repairItem.isEnabled = true
        menu.addItem(repairItem)
        
        menu.addItem(NSMenuItem.separator())
        
        // Service Control Actions
        let startItem = NSMenuItem(title: "Start Tor", action: #selector(startTor), keyEquivalent: "s")
        startItem.target = self
        startItem.isEnabled = true
        startItem.tag = 201
        menu.addItem(startItem)
        
        let stopItem = NSMenuItem(title: "Stop Tor", action: #selector(stopTor), keyEquivalent: "x")
        stopItem.target = self
        stopItem.isEnabled = true
        stopItem.tag = 202
        menu.addItem(stopItem)
        
        let restartItem = NSMenuItem(title: "Restart Tor", action: #selector(restartTor), keyEquivalent: "r")
        restartItem.target = self
        restartItem.isEnabled = true
        restartItem.tag = 203
        menu.addItem(restartItem)
        
        menu.addItem(NSMenuItem.separator())
        
        // Help and Tools
        let helpItem = NSMenuItem(title: "Proxy Configuration...", action: #selector(showProxyHelp), keyEquivalent: "h")
        helpItem.target = self
        helpItem.isEnabled = true
        menu.addItem(helpItem)
        
        let logItem = NSMenuItem(title: "Open Logs", action: #selector(openLog), keyEquivalent: "l")
        logItem.target = self
        logItem.isEnabled = true
        menu.addItem(logItem)
        
        menu.addItem(NSMenuItem.separator())
        
        let quitItem = NSMenuItem(title: "Quit", action: #selector(quit), keyEquivalent: "q")
        quitItem.target = self
        quitItem.isEnabled = true
        menu.addItem(quitItem)
        
        self.myMenu = menu
    }
    
    @objc func statusBarButtonClicked(_ sender: NSStatusBarButton) {
        NSApp.activate(ignoringOtherApps: true)
        if let menu = myMenu {
            statusItem?.popUpMenu(menu)
        }
    }
    
    @objc func copyIPToClipboard() {
        if currentIP != "N/A" && currentIP != "Waiting..." && currentIP != "Connection Error" && currentIP != "Error" {
            let pasteboard = NSPasteboard.general
            pasteboard.declareTypes([.string], owner: nil)
            pasteboard.setString(currentIP, forType: .string)
            
            sendNotification(title: "IP Copied", message: "\(currentIP) copied to clipboard.")
        }
    }
    
    @objc func newIdentity() {
        // Attempt sending NEWNYM signal to Control Port (9051)
        let task = Process()
        task.launchPath = "/bin/bash"
        task.arguments = ["-c", "echo -e 'AUTHENTICATE \"\"\r\nSIGNAL NEWNYM\r\nQUIT' | nc -w 1 127.0.0.1 9051"]
        let pipe = Pipe()
        task.standardOutput = pipe
        
        do {
            try task.run()
            task.waitUntilExit()
            
            let output = String(data: pipe.fileHandleForReading.readDataToEndOfFile(), encoding: .utf8) ?? ""
            if output.contains("250 OK") {
                sendNotification(title: "New Identity", message: "New identity signal sent successfully (NEWNYM).")
            } else {
                // Fallback: restart service if control port is inactive
                sendNotification(title: "Changing IP", message: "Control port (9051) inactive. Restarting Tor service...")
                runShellCommand("/opt/homebrew/bin/brew", arguments: ["services", "restart", "tor"])
            }
        } catch {
            runShellCommand("/opt/homebrew/bin/brew", arguments: ["services", "restart", "tor"])
        }
        
        updateStatus()
    }
    
    @objc func repairTor() {
        sendNotification(title: "Repairing Tor", message: "Stopping Tor and clearing cache...")
        
        // Stop the service
        runShellCommand("/opt/homebrew/bin/brew", arguments: ["services", "stop", "tor"])
        
        // Clear local connection cache
        let fileManager = FileManager.default
        let torDir = NSHomeDirectory() + "/.tor"
        if let files = try? fileManager.contentsOfDirectory(atPath: torDir) {
            for file in files {
                if file.hasPrefix("cached-") {
                    try? fileManager.removeItem(atPath: torDir + "/" + file)
                }
            }
        }
        
        // Restart the service
        runShellCommand("/opt/homebrew/bin/brew", arguments: ["services", "start", "tor"])
        
        sendNotification(title: "Tor Repaired", message: "Connection cache cleared and Tor restarted.")
        updateStatus()
    }
    
    @objc func startTor() {
        runShellCommand("/opt/homebrew/bin/brew", arguments: ["services", "start", "tor"])
        updateStatus()
    }
    
    @objc func stopTor() {
        runShellCommand("/opt/homebrew/bin/brew", arguments: ["services", "stop", "tor"])
        updateStatus()
    }
    
    @objc func restartTor() {
        runShellCommand("/opt/homebrew/bin/brew", arguments: ["services", "restart", "tor"])
        updateStatus()
    }
    
    @objc func openLog() {
        let logPath = "/opt/homebrew/var/log/tor.log"
        if FileManager.default.fileExists(atPath: logPath) {
            NSWorkspace.shared.open(URL(fileURLWithPath: logPath))
        } else {
            NSWorkspace.shared.open(URL(fileURLWithPath: "/opt/homebrew/etc/tor"))
        }
    }
    
    @objc func showProxyHelp() {
        let alert = NSAlert()
        alert.messageText = "Tor Proxy Configuration"
        alert.informativeText = """
        To route your applications' traffic through Tor, configure this SOCKS5 proxy:
        
        • Host: 127.0.0.1 (or localhost)
        • Port: 9050
        
        --- APPLICATION SETUP EXAMPLES ---
        
        1. Web Browser (Firefox):
           Preferences > Network Settings > Manual proxy configuration.
           Fill only "SOCKS Host" with 127.0.0.1 and port 9050 (choose SOCKS v5).
        
        2. Terminal (cURL, wget, etc.):
           export ALL_PROXY=socks5h://127.0.0.1:9050
        
        3. Python (requests):
           proxies = {
               'http': 'socks5h://127.0.0.1:9050',
               'https': 'socks5h://127.0.0.1:9050'
           }
        """
        alert.alertStyle = .informational
        alert.addButton(withTitle: "OK")
        alert.runModal()
    }
    
    @objc func quit() {
        NSApplication.shared.terminate(self)
    }
    
    func runShellCommand(_ launchPath: String, arguments: [String]) {
        let task = Process()
        task.launchPath = launchPath
        task.arguments = arguments
        try? task.run()
        task.waitUntilExit()
    }
    
    func sendNotification(title: String, message: String) {
        let script = "display notification \"\(message)\" with title \"🧅 \(title)\""
        let task = Process()
        task.launchPath = "/usr/bin/osascript"
        task.arguments = ["-e", script]
        try? task.run()
    }
    
    func updateStatus() {
        let running = isTorRunning()
        let responding = isTorResponding()
        
        if running && responding {
            fetchTorVersion()
            fetchTorCircuit()
            fetchTorIP()
        } else {
            self.currentIP = "N/A"
            self.torCircuit = "None"
        }
        
        DispatchQueue.main.async { [weak self] in
            guard let self = self else { return }
            
            let statusText: String
            let icon: String
            let isOnline = running && responding
            
            if isOnline {
                statusText = "Status: Online 🟢"
                icon = "🧅"
            } else if running {
                statusText = "Status: Starting... 🟡"
                icon = "🟡"
            } else {
                statusText = "Status: Stopped 🔴"
                icon = "⚪"
            }
            
            if let button = self.statusItem?.button {
                button.title = icon
            }
            
            if let menu = self.myMenu {
                if let statusItemMenu = menu.item(withTag: 101) {
                    statusItemMenu.title = statusText
                }
                
                if let ipItemMenu = menu.item(withTag: 102) {
                    ipItemMenu.title = "Tor IP: \(self.currentIP)"
                    ipItemMenu.isEnabled = isOnline && self.currentIP != "Waiting..." && self.currentIP != "Connection Error"
                }
                
                if let versionItemMenu = menu.item(withTag: 103) {
                    versionItemMenu.title = "Tor Version: \(self.torVersion)"
                }
                
                if let circuitItemMenu = menu.item(withTag: 104) {
                    circuitItemMenu.title = "Tor Circuit: \(self.torCircuit)"
                }
                
                if let identityItem = menu.item(withTag: 301) {
                    identityItem.isEnabled = isOnline
                }
                
                if let startItem = menu.item(withTag: 201) {
                    startItem.isEnabled = !running
                }
                if let stopItem = menu.item(withTag: 202) {
                    stopItem.isEnabled = running
                }
                if let restartItem = menu.item(withTag: 203) {
                    restartItem.isEnabled = running
                }
            }
        }
    }
    
    func isTorRunning() -> Bool {
        let task = Process()
        task.launchPath = "/usr/bin/pgrep"
        task.arguments = ["-x", "tor"]
        let pipe = Pipe()
        task.standardOutput = pipe
        try? task.run()
        task.waitUntilExit()
        return task.terminationStatus == 0
    }
    
    func isTorResponding() -> Bool {
        let task = Process()
        task.launchPath = "/usr/bin/nc"
        task.arguments = ["-z", "-G", "2", "127.0.0.1", "9050"]
        try? task.run()
        task.waitUntilExit()
        return task.terminationStatus == 0
    }
    
    func fetchTorVersion() {
        guard torVersion == "Unknown" else { return }
        
        DispatchQueue.global(qos: .background).async { [weak self] in
            guard let self = self else { return }
            
            let task = Process()
            task.launchPath = "/bin/bash"
            task.arguments = ["-c", "echo -e 'AUTHENTICATE \"\"\r\nGETINFO version\r\nQUIT' | nc -w 1 127.0.0.1 9051"]
            let pipe = Pipe()
            task.standardOutput = pipe
            
            do {
                try task.run()
                task.waitUntilExit()
                
                if task.terminationStatus == 0 {
                    let data = pipe.fileHandleForReading.readDataToEndOfFile()
                    if let output = String(data: data, encoding: .utf8),
                       let version = self.parseVersion(from: output) {
                        self.torVersion = version
                    }
                }
            } catch {
                self.torVersion = "Error"
            }
            
            DispatchQueue.main.async {
                if let menu = self.myMenu, let versionItemMenu = menu.item(withTag: 103) {
                    versionItemMenu.title = "Tor Version: \(self.torVersion)"
                }
            }
        }
    }
    
    func parseVersion(from output: String) -> String? {
        let lines = output.components(separatedBy: .newlines)
        for line in lines {
            if line.contains("version=") {
                let parts = line.components(separatedBy: "=")
                if parts.count > 1 {
                    return parts[1].trimmingCharacters(in: .whitespacesAndNewlines)
                }
            }
        }
        return nil
    }
    
    func fetchTorCircuit() {
        DispatchQueue.global(qos: .background).async { [weak self] in
            guard let self = self else { return }
            
            let task = Process()
            task.launchPath = "/bin/bash"
            task.arguments = ["-c", "echo -e 'AUTHENTICATE \"\"\r\nGETINFO circuit-status\r\nQUIT' | nc -w 1 127.0.0.1 9051"]
            let pipe = Pipe()
            task.standardOutput = pipe
            
            do {
                try task.run()
                task.waitUntilExit()
                
                if task.terminationStatus == 0 {
                    let data = pipe.fileHandleForReading.readDataToEndOfFile()
                    if let output = String(data: data, encoding: .utf8) {
                        self.torCircuit = self.parseCircuit(from: output) ?? "None"
                    }
                } else {
                    self.torCircuit = "None"
                }
            } catch {
                self.torCircuit = "Error"
            }
            
            DispatchQueue.main.async {
                if let menu = self.myMenu, let circuitItemMenu = menu.item(withTag: 104) {
                    circuitItemMenu.title = "Tor Circuit: \(self.torCircuit)"
                }
            }
        }
    }
    
    func parseCircuit(from output: String) -> String? {
        let lines = output.components(separatedBy: .newlines)
        for line in lines.reversed() {
            if line.contains("BUILT") && line.contains("PURPOSE=GENERAL") {
                let parts = line.components(separatedBy: " ")
                guard parts.count > 2 else { continue }
                let pathPart = parts[2]
                let relays = pathPart.components(separatedBy: ",")
                var names: [String] = []
                for relay in relays {
                    if let tildeIndex = relay.firstIndex(of: "~") {
                        let name = String(relay[relay.index(after: tildeIndex)...])
                        names.append(name)
                    }
                }
                if !names.isEmpty {
                    return names.joined(separator: " ➔ ")
                }
            }
        }
        return nil
    }
    
    func fetchTorIP() {
        guard !isFetchingIP else { return }
        isFetchingIP = true
        
        DispatchQueue.global(qos: .background).async { [weak self] in
            guard let self = self else { return }
            
            let task = Process()
            task.launchPath = "/usr/bin/curl"
            task.arguments = ["-s", "--socks5-hostname", "127.0.0.1:9050", "https://check.torproject.org/api/ip"]
            let pipe = Pipe()
            task.standardOutput = pipe
            
            do {
                try task.run()
                task.waitUntilExit()
                
                if task.terminationStatus == 0 {
                    let data = pipe.fileHandleForReading.readDataToEndOfFile()
                    if let jsonString = String(data: data, encoding: .utf8),
                       let ip = self.parseIP(from: jsonString) {
                        self.currentIP = ip
                    } else {
                        self.currentIP = "Unknown"
                    }
                } else {
                    self.currentIP = "Connection Error"
                }
            } catch {
                self.currentIP = "Error"
            }
            
            self.isFetchingIP = false
            
            DispatchQueue.main.async {
                if let menu = self.myMenu, let ipItemMenu = menu.item(withTag: 102) {
                    ipItemMenu.title = "Tor IP: \(self.currentIP)"
                    let isOnline = self.isTorRunning() && self.isTorResponding()
                    ipItemMenu.isEnabled = isOnline && self.currentIP != "Waiting..." && self.currentIP != "Connection Error"
                }
            }
        }
    }
    
    func parseIP(from json: String) -> String? {
        if let range = json.range(of: "\"IP\":\"") {
            let start = range.upperBound
            if let endRange = json.range(of: "\"", range: start..<json.endIndex) {
                return String(json[start..<endRange.lowerBound])
            }
        }
        return nil
    }
}

let app = NSApplication.shared
let delegate = AppDelegate()
strongDelegateReference = delegate
app.delegate = delegate
app.setActivationPolicy(.accessory)
app.run()
