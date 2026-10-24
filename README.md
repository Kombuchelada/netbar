<img src="docs/images/icon.png" width="96" alt="Netbar icon">

# Netbar

A menu bar icon that shows whether your Mac is using Ethernet or Wi-Fi.

A MacBook keeps Wi-Fi connected when you plug in Ethernet, so the Wi-Fi icon stays lit and you can't tell which one your traffic is actually going over. Netbar shows the connection macOS is using right now:

| Icon | Meaning |
| --- | --- |
| `cable.connector.horizontal` | Ethernet |
| `wifi` | Wi-Fi |
| `network` | Something else (for example a VPN or iPhone USB) |
| `wifi.slash` | No connection |

Click it to see the interface name (for example `Ethernet (en7)`), turn on **Open at Login**, or quit.

## Install

```sh
brew install --cask kombuchelada/tap/netbar
```

Netbar isn't notarized, so macOS blocks it the first time it opens. Open it once, then click **Open Anyway** in System Settings > Privacy & Security. Or run:

```sh
xattr -dr com.apple.quarantine /Applications/Netbar.app
```

Requires macOS 14 Sonoma or later.

## Build from source

```sh
./scripts/build-app.sh --install   # builds build/Netbar.app and copies it to ~/Applications
```

## How it works

Netbar uses `NWPathMonitor` from Apple's Network framework, which reports the path macOS uses by default for outgoing traffic. It updates as soon as that path changes. It doesn't poll and doesn't need any permissions.
