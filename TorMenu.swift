import AppKit
import Foundation

// Référence globale forte
var strongDelegateReference: AppDelegate?

class AppDelegate: NSObject, NSApplicationDelegate {
    var statusItem: NSStatusItem?
    var myMenu: NSMenu?
    var timer: Timer?
    var currentIP: String = "En attente..."
    var isFetchingIP: Bool = false
    
    func applicationDidFinishLaunching(_ notification: Notification) {
        // Empêche macOS de suspendre l'application
        UserDefaults.standard.set(false, forKey: "NSSupportsAutomaticTermination")
        ProcessInfo.processInfo.disableAutomaticTermination("Surveillance Tor active")
        
        // Configuration de la Status Bar
        statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
        if let button = statusItem?.button {
            button.title = "⚪"
            button.toolTip = "Surveillance Tor"
            button.target = self
            button.action = #selector(statusBarButtonClicked(_:))
        }
        
        constructMenu()
        updateStatus()
        
        // Timer de surveillance toutes les 5 secondes
        timer = Timer.scheduledTimer(withTimeInterval: 5.0, repeats: true) { [weak self] _ in
            self?.updateStatus()
        }
    }
    
    func constructMenu() {
        let menu = NSMenu()
        menu.autoenablesItems = false
        
        // Section Statut et IP
        let statusItemMenu = NSMenuItem(title: "Statut: Vérification...", action: nil, keyEquivalent: "")
        statusItemMenu.isEnabled = false
        statusItemMenu.tag = 101
        menu.addItem(statusItemMenu)
        
        let ipItemMenu = NSMenuItem(title: "IP Tor: En attente...", action: #selector(copyIPToClipboard), keyEquivalent: "c")
        ipItemMenu.target = self
        ipItemMenu.isEnabled = false
        ipItemMenu.toolTip = "Cliquez pour copier l'IP dans le presse-papiers"
        ipItemMenu.tag = 102
        menu.addItem(ipItemMenu)
        
        menu.addItem(NSMenuItem.separator())
        
        // Actions Rapides
        let identityItem = NSMenuItem(title: "Nouvelle Identité (Changer d'IP)", action: #selector(newIdentity), keyEquivalent: "n")
        identityItem.target = self
        identityItem.isEnabled = true
        identityItem.tag = 301
        menu.addItem(identityItem)
        
        let repairItem = NSMenuItem(title: "Réparer Tor (Vider le cache)", action: #selector(repairTor), keyEquivalent: "f")
        repairItem.target = self
        repairItem.isEnabled = true
        menu.addItem(repairItem)
        
        menu.addItem(NSMenuItem.separator())
        
        // Actions de contrôle
        let startItem = NSMenuItem(title: "Démarrer Tor", action: #selector(startTor), keyEquivalent: "s")
        startItem.target = self
        startItem.isEnabled = true
        startItem.tag = 201
        menu.addItem(startItem)
        
        let stopItem = NSMenuItem(title: "Arrêter Tor", action: #selector(stopTor), keyEquivalent: "x")
        stopItem.target = self
        stopItem.isEnabled = true
        stopItem.tag = 202
        menu.addItem(stopItem)
        
        let restartItem = NSMenuItem(title: "Redémarrer Tor", action: #selector(restartTor), keyEquivalent: "r")
        restartItem.target = self
        restartItem.isEnabled = true
        restartItem.tag = 203
        menu.addItem(restartItem)
        
        menu.addItem(NSMenuItem.separator())
        
        // Aide et Outils
        let helpItem = NSMenuItem(title: "Configuration du Proxy...", action: #selector(showProxyHelp), keyEquivalent: "h")
        helpItem.target = self
        helpItem.isEnabled = true
        menu.addItem(helpItem)
        
        let logItem = NSMenuItem(title: "Ouvrir les logs", action: #selector(openLog), keyEquivalent: "l")
        logItem.target = self
        logItem.isEnabled = true
        menu.addItem(logItem)
        
        menu.addItem(NSMenuItem.separator())
        
        let quitItem = NSMenuItem(title: "Quitter", action: #selector(quit), keyEquivalent: "q")
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
        if currentIP != "N/A" && currentIP != "En attente..." && currentIP != "Erreur de connexion" && currentIP != "Erreur" {
            let pasteboard = NSPasteboard.general
            pasteboard.declareTypes([.string], owner: nil)
            pasteboard.setString(currentIP, forType: .string)
            
            sendNotification(title: "IP Copiée", message: "\(currentIP) a été copiée dans le presse-papiers.")
        }
    }
    
    @objc func newIdentity() {
        // Tente d'envoyer le signal NEWNYM sur le Port de Contrôle (9051)
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
                sendNotification(title: "Nouvelle Identité", message: "Signal de nouvelle identité envoyé avec succès (NEWNYM).")
            } else {
                // Si le port de contrôle est fermé, on redémarre le service en fallback
                sendNotification(title: "Changement d'IP", message: "Port de contrôle (9051) inactif. Redémarrage du service Tor...")
                runShellCommand("/opt/homebrew/bin/brew", arguments: ["services", "restart", "tor"])
            }
        } catch {
            runShellCommand("/opt/homebrew/bin/brew", arguments: ["services", "restart", "tor"])
        }
        
        updateStatus()
    }
    
    @objc func repairTor() {
        sendNotification(title: "Réparation de Tor", message: "Arrêt de Tor et nettoyage du cache...")
        
        // Arrête le service
        runShellCommand("/opt/homebrew/bin/brew", arguments: ["services", "stop", "tor"])
        
        // Vide le cache
        let fileManager = FileManager.default
        let torDir = NSHomeDirectory() + "/.tor"
        if let files = try? fileManager.contentsOfDirectory(atPath: torDir) {
            for file in files {
                if file.hasPrefix("cached-") {
                    try? fileManager.removeItem(atPath: torDir + "/" + file)
                }
            }
        }
        
        // Redémarre le service
        runShellCommand("/opt/homebrew/bin/brew", arguments: ["services", "start", "tor"])
        
        sendNotification(title: "Tor Réparé", message: "Le cache de connexion a été vidé et Tor a redémarré.")
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
        alert.messageText = "Configuration du Proxy Tor"
        alert.informativeText = """
        Pour utiliser Tor avec vos applications, configurez le proxy SOCKS5 suivant :
        
        • Hôte : 127.0.0.1 (ou localhost)
        • Port : 9050
        
        --- CONFIGURATION PAR APPLICATION ---
        
        1. Navigateur (Firefox) :
           Préférences > Paramètres réseau > Configuration manuelle du proxy.
           Remplir uniquement "Hôte SOCKS" avec 127.0.0.1 et le port 9050 (choisir SOCKS v5).
        
        2. Terminal (cURL, wget, etc.) :
           export ALL_PROXY=socks5h://127.0.0.1:9050
        
        3. Python (requests) :
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
            fetchTorIP()
        } else {
            self.currentIP = "N/A"
        }
        
        DispatchQueue.main.async { [weak self] in
            guard let self = self else { return }
            
            let statusText: String
            let icon: String
            let isOnline = running && responding
            
            if isOnline {
                statusText = "Statut: En ligne 🟢"
                icon = "🧅"
            } else if running {
                statusText = "Statut: Démarrage... 🟡"
                icon = "🟡"
            } else {
                statusText = "Statut: Arrêté 🔴"
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
                    ipItemMenu.title = "IP Tor: \(self.currentIP)"
                    ipItemMenu.isEnabled = isOnline && self.currentIP != "En attente..." && self.currentIP != "Erreur de connexion"
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
                        self.currentIP = "Inconnue"
                    }
                } else {
                    self.currentIP = "Erreur de connexion"
                }
            } catch {
                self.currentIP = "Erreur"
            }
            
            self.isFetchingIP = false
            
            DispatchQueue.main.async {
                if let menu = self.myMenu, let ipItemMenu = menu.item(withTag: 102) {
                    ipItemMenu.title = "IP Tor: \(self.currentIP)"
                    let isOnline = self.isTorRunning() && self.isTorResponding()
                    ipItemMenu.isEnabled = isOnline && self.currentIP != "En attente..." && self.currentIP != "Erreur de connexion"
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
