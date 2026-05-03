# 🛡️ GEOIP-BlockDewd

> Automated blocklist management for [geoip-shell](https://github.com/friendly-bits/geoip-shell) — reduce IP set bloat and minimize hardware impact with a set-and-forget approach.

[![License](https://img.shields.io/github/license/dewdmadbro/geoip-blockdewd)](https://github.com/dewdmadbro/geoip-blockdewd/blob/main/LICENSE.md)
[![Latest Release](https://img.shields.io/github/v/release/dewdmadbro/geoip-blockdewd)](https://github.com/dewdmadbro/geoip-blockdewd/releases/latest)

---

## 📋 Overview

**GEOIP-BlockDewd** is a companion tool for [geoip-shell](https://github.com/friendly-bits/geoip-shell) that automates the fetching, deduplication, and importing of IP blocklists. It intelligently filters out IPs already blocked by geoip-shell's geo-blocking rules, keeping your `ipset` entries lean and reducing unnecessary load on your hardware.

Designed to run as a **systemd service**, it provides a fully automated, set-and-forget experience once configured. It can also optionally add **kernel logging** to geoip-shell drop rules for enhanced visibility.

---

## ✨ Features

| Feature | Description |
|---|---|
| 📝 **YAML Configuration** | Simple, human-readable config via `config.yaml` |
| 🔄 **Automated Updates** | Scheduled blocklist fetching & importing (default: every 24h, configurable) |
| 🧹 **Duplicate Filtering** | Removes duplicate entries from all fetched lists |
| 🌍 **Geo-Aware Filtering** | Cross-references IPs against geoip-shell's geo-blocking lists to avoid redundancy |
| 📊 **Import Statistics** | Provides a summary of fetched, filtered, and imported IPs |
| 📝 **Optional Logging** | Adds a `GEOIP-DROP` mangle chain for kernel-level logging of dropped packets |
| 🗑️ **Clean Removal** | Full uninstall support, including optional dependency cleanup |

---

## ⚙️ Requirements

- **Linux** (tested on Linux Mint; Ubuntu/Debian-based distros expected to work)
- **[geoip-shell](https://github.com/friendly-bits/geoip-shell)** — must be installed and configured first
- **iptables & ipset** — only iptables mode is supported
- **systemd** — for scheduling and automation
- **yq** & **grepcidr** — auto-installed during setup if missing

---

## 🚀 Installation

### 1. Download the latest release

```bash
LOCATION=$(curl -s https://api.github.com/repos/dewdmadbro/geoip-blockdewd/releases/latest \
  | grep "tarball_url" \
  | awk '{ print $2 }' \
  | sed 's/,$//' \
  | sed 's/"//g') \
  ; curl -L -o geoip-blockdewd.tar.gz $LOCATION
```

### 2. Extract the archive

```bash
tar -xvzf geoip-blockdewd.tar.gz --one-top-level --strip-components=1
rm geoip-blockdewd.tar.gz
```

### 3. Configure

```bash
cd geoip-blockdewd
nano config.yaml
```

> ⚠️ **Important:** You **must** set your `blocking_mode` in `config.yaml` (`whitelist` or `blacklist`) matching your geoip-shell setup, or the script will not run.

You can also customize:
- `systemd_timer` — interval in hours between blocklist updates
- `fetch_urls1` / `fetch_urls2` — additional blocklist URLs to pull from

### 4. Install the service

```bash
chmod +x geoip-shelldewd.sh
sudo ./geoip-shelldewd.sh install
```

This will:
- Install `yq` and `grepcidr` if missing
- Create and enable the systemd service and timer
- Run the service for the first time
- Generate a log file (`geoip-blockdewd.log`) in the extracted folder

---

## 📝 Optional: Enable Drop Logging

To add kernel-level logging for dropped packets:

```bash
sudo ./geoip-shelldewd.sh logdrop
```

This will:
1. Backup and modify `geoip-shell-lib-common.sh` and `geoip-shell-lib-ipt.sh`
2. Create a new `GEOIP-DROP` mangle chain with logging rules
3. Redirect blocked traffic through the logging chain

View logs in real-time:

```bash
sudo tail -f /var/log/kern.log
```

---

## 🧰 Usage & Management

| Command | Description |
|---|---|
| `sudo ./geoip-shelldewd.sh install` | Install service, timer, and dependencies |
| `sudo ./geoip-shelldewd.sh run` | Manually trigger a blocklist update |
| `sudo ./geoip-shelldewd.sh logdrop` | Enable kernel logging for dropped packets |
| `sudo ./geoip-shelldewd.sh removelog` | Remove logging customizations |
| `sudo ./geoip-shelldewd.sh remove` | Uninstall service and timer |
| `sudo ./geoip-shelldewd.sh update` | Update to the latest version |

### Check service status

```bash
sudo systemctl status geoip-blockdewd
sudo systemctl list-timers
```

---

## 🧹 Removal

### Remove the service & timer

```bash
cd geoip-blockdewd
sudo ./geoip-shelldewd.sh remove
```

This will disable and remove the systemd service/timer, reload the daemon, and optionally remove `yq` and `grepcidr`.

### Remove logging customizations

```bash
sudo ./geoip-shelldewd.sh removelog
```

This restores original geoip-shell files, reverts mangle rules, and removes the `GEOIP-DROP` chain.

---

## 🔄 Updating

```bash
cd geoip-blockdewd
sudo ./geoip-shelldewd.sh update
```

This downloads the latest release and overwrites files **except** `config.yaml`, preserving your settings.

---

## 📁 Project Structure

```
geoip-blockdewd/
├── config.yaml            # Configuration file (blocking mode, timer, URLs)
├── geoip-blockdewd.sh     # Core script — fetches, filters, and imports blocklists
├── geoip-shelldewd.sh     # Installer/manager — handles install, remove, logging, updates
└── README.md
```

---

## ⚠️ Disclaimer

> This was developed and tested on **Linux Mint**. Ubuntu and other Debian-based distributions should work similarly. This is a personal project built while learning — it works well for my use case but may not suit everyone. Use at your own discretion and feel free to contribute improvements!

---

## 🙏 Credits

This tool would not exist without the excellent work of **[friendly-bits/geoip-shell](https://github.com/friendly-bits/geoip-shell)**. If you're using this, please consider giving that project a ⭐ as well.

---

## 📄 License

This project is available for use under the terms of the repository license.
