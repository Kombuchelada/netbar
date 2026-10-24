import AppKit
import Network
import ServiceManagement

/// What the Mac is using for its internet traffic right now.
enum Connection: Equatable {
    case ethernet, wifi, other, offline

    init(_ path: NWPath) {
        if path.status != .satisfied {
            self = .offline
        } else if path.usesInterfaceType(.wiredEthernet) {
            self = .ethernet
        } else if path.usesInterfaceType(.wifi) {
            self = .wifi
        } else {
            self = .other
        }
    }

    var title: String {
        switch self {
        case .ethernet: "Ethernet"
        case .wifi: "Wi-Fi"
        case .other: "Other connection"
        case .offline: "No connection"
        }
    }

    var symbol: String {
        switch self {
        case .ethernet: "cable.connector.horizontal"
        case .wifi: "wifi"
        case .other: "network"
        case .offline: "wifi.slash"
        }
    }
}

@MainActor
final class AppDelegate: NSObject, NSApplicationDelegate {
    private let statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.squareLength)
    private let monitor = NWPathMonitor()
    private let connectionItem = NSMenuItem()
    private let loginItem = NSMenuItem(title: "Open at Login", action: #selector(toggleOpenAtLogin), keyEquivalent: "")

    func applicationDidFinishLaunching(_ notification: Notification) {
        let menu = NSMenu()
        menu.delegate = self
        connectionItem.isEnabled = false
        menu.addItem(connectionItem)
        menu.addItem(.separator())
        loginItem.target = self
        menu.addItem(loginItem)
        menu.addItem(NSMenuItem(title: "Quit Netbar", action: #selector(NSApplication.terminate(_:)), keyEquivalent: "q"))
        statusItem.menu = menu

        monitor.pathUpdateHandler = { path in
            let connection = Connection(path)
            let interface = path.availableInterfaces.first?.name
            Task { @MainActor in self.show(connection, interface: interface) }
        }
        monitor.start(queue: .main)
    }

    private func show(_ connection: Connection, interface: String?) {
        let image = NSImage(systemSymbolName: connection.symbol, accessibilityDescription: connection.title)
        image?.isTemplate = true
        statusItem.button?.image = image
        statusItem.button?.toolTip = connection.title
        if let interface, connection != .offline {
            connectionItem.title = "\(connection.title) (\(interface))"
        } else {
            connectionItem.title = connection.title
        }
    }

    @objc private func toggleOpenAtLogin() {
        do {
            if SMAppService.mainApp.status == .enabled {
                try SMAppService.mainApp.unregister()
            } else {
                try SMAppService.mainApp.register()
            }
        } catch {
            NSAlert(error: error).runModal()
        }
    }
}

extension AppDelegate: NSMenuDelegate {
    func menuNeedsUpdate(_ menu: NSMenu) {
        loginItem.state = SMAppService.mainApp.status == .enabled ? .on : .off
    }
}

let app = NSApplication.shared
let delegate = AppDelegate()
app.delegate = delegate
app.setActivationPolicy(.accessory)
app.run()
