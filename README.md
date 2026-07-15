# TorMenu 🧅

**TorMenu** is a lightweight macOS menu bar utility designed to monitor and manage your local **Tor** service (installed via Homebrew). It displays your active Tor connection status, shows your public Tor IP address, allows copying the IP with one click, and provides quick shortcuts to request a new identity, repair Tor, or start/stop the daemon.

---

## Features

* **Dynamic Status Icon** in the macOS menu bar:
  * 🧅 : Tor is online and connected (Bootstrapped 100%).
  * 🟡 : Tor is starting up or connecting.
  * ⚪ : Tor is stopped or unreachable.
* **Tor IP Display & Copy**: Displays the public IP address of your current Tor circuit. Click the menu item to copy the IP directly to your clipboard (triggers a native macOS notification).
* **New Identity (Request New IP)**: Renews your Tor circuits to request a new IP address instantly (uses the Tor ControlPort, falls back to service restart if port is closed).
* **Repair Tor (Clear Cache)**: A troubleshooting shortcut that stops Tor, deletes local connection cache files (`~/.tor/cached-*`), and restarts Tor. Ideal when Tor gets stuck bootstrapping or fails to build circuits.
* **Service Controls**: Easily Start, Stop, or Restart the Tor service.
* **Log Access**: Quick access to `/opt/homebrew/var/log/tor.log` for debugging.
* **Proxy Help Utility**: Built-in instructions on configuring browsers, terminals, or scripts to route traffic through Tor.

---

## Prerequisites

Tor must be installed on your Mac using Homebrew:
```bash
brew install tor
```

### Recommended Setup (Control Port)
For the **New Identity (Request New IP)** feature to work instantly (without restarting the whole Tor service), enable the local Tor control port:

1. Edit your Tor configuration file `/opt/homebrew/etc/tor/torrc` (create it if it doesn't exist):
   ```bash
   nano /opt/homebrew/etc/tor/torrc
   ```
2. Add the following line:
   ```text
   ControlPort 9051
   ```
3. Restart Tor to apply the changes:
   ```bash
   brew services restart tor
   ```

---

## Installation and Usage

1. **Clone or download** this repository.
2. Open a terminal in the project directory and run the installation script:
   ```bash
   chmod +x build_app.sh
   ./build_app.sh
   ```
   This script will compile the code, bundle it into a native macOS **`TorMenu.app`**, copy it into your **`/Applications`** folder, and register it to launch automatically at login.


---

## Proxy Configuration

By default, Tor listens as a SOCKS5 proxy on:
* **Host**: `127.0.0.1` (or `localhost`)
* **Port**: `9050`

### 1. Terminal (cURL, Wget, etc.)
To route your current terminal session traffic through Tor:
```bash
export ALL_PROXY=socks5h://127.0.0.1:9050
```
*Note: Using the `socks5h://` scheme ensures DNS resolution is performed by Tor, preventing DNS leaks.*

To test in your terminal:
```bash
curl https://check.torproject.org/api/ip
```

### 2. Web Browser (Firefox - Recommended)
1. Navigate to **Preferences** > **Network Settings**.
2. Click **Settings...**
3. Select **Manual proxy configuration**.
4. Fill **only** the **SOCKS Host** field with `127.0.0.1` and the **Port** with `9050`.
5. Check **SOCKS v5**.
6. Check **Proxy DNS when using SOCKS v5** (critical for privacy).

### 3. Python Scripts
```python
import requests

proxies = {
    'http': 'socks5h://127.0.0.1:9050',
    'https': 'socks5h://127.0.0.1:9050'
}

response = requests.get('https://check.torproject.org/api/ip', proxies=proxies)
print(response.json())
```

---

## License

This project is licensed under the MIT License. See the [LICENSE](LICENSE) file for details.
