import AppKit
import ServiceManagement

@MainActor
final class AppDelegate: NSObject, NSApplicationDelegate {
    private let controller = NommoController()
    private let statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
    private let statusMenuItem = NSMenuItem(title: "Starting…", action: nil, keyEquivalent: "")
    private let launchAtLoginItem = NSMenuItem(title: "Launch at Login", action: #selector(toggleLaunchAtLogin), keyEquivalent: "")
    private var gainItems: [NSMenuItem] = []

    func applicationDidFinishLaunching(_ notification: Notification) {
        configureMenu()
        configureLaunchAtLoginOnce()
        controller.onStateChange = { [weak self] in self?.refreshMenu() }
        controller.start()
        refreshMenu()
    }

    func applicationWillTerminate(_ notification: Notification) {
        controller.stop()
    }

    private func configureMenu() {
        statusItem.button?.image = NSImage(systemSymbolName: "speaker.wave.1.fill", accessibilityDescription: "Nommo Night")
        statusItem.button?.toolTip = "Nommo Night"

        let menu = NSMenu()
        statusMenuItem.isEnabled = false
        menu.addItem(statusMenuItem)
        menu.addItem(.separator())

        for decibels in [-12.0, -18.0, -24.0, -30.0] {
            let item = NSMenuItem(title: "\(Int(decibels)) dB", action: #selector(selectGain(_:)), keyEquivalent: "")
            item.target = self
            item.representedObject = decibels
            gainItems.append(item)
            menu.addItem(item)
        }

        menu.addItem(.separator())
        launchAtLoginItem.target = self
        menu.addItem(launchAtLoginItem)
        menu.addItem(.separator())

        let quit = NSMenuItem(title: "Quit Nommo Night", action: #selector(NSApplication.terminate(_:)), keyEquivalent: "q")
        menu.addItem(quit)
        statusItem.menu = menu
    }

    private func configureLaunchAtLoginOnce() {
        let key = "didConfigureLaunchAtLogin"
        guard !UserDefaults.standard.bool(forKey: key) else { return }

        do {
            if SMAppService.mainApp.status != .enabled {
                try SMAppService.mainApp.register()
            }
            UserDefaults.standard.set(true, forKey: key)
        } catch {
            statusMenuItem.title = "Login item error — \(error.localizedDescription)"
        }
    }

    private func refreshMenu() {
        switch controller.state {
        case .inactive:
            statusMenuItem.title = "Idle — Nommo not selected"
            statusItem.button?.image = NSImage(systemSymbolName: "speaker.slash", accessibilityDescription: "Nommo Night idle")
        case .active:
            statusMenuItem.title = "Active — \(Int(controller.gainDecibels)) dB"
            statusItem.button?.image = NSImage(systemSymbolName: "speaker.wave.1.fill", accessibilityDescription: "Nommo Night active")
        case .failed(let message):
            statusMenuItem.title = "Error — \(message)"
            statusItem.button?.image = NSImage(systemSymbolName: "exclamationmark.triangle", accessibilityDescription: "Nommo Night error")
        }

        for item in gainItems {
            item.state = (item.representedObject as? Double) == controller.gainDecibels ? .on : .off
        }
        launchAtLoginItem.state = SMAppService.mainApp.status == .enabled ? .on : .off
    }

    @objc private func selectGain(_ sender: NSMenuItem) {
        guard let decibels = sender.representedObject as? Double else { return }
        controller.setGain(decibels: decibels)
        refreshMenu()
    }

    @objc private func toggleLaunchAtLogin() {
        do {
            if SMAppService.mainApp.status == .enabled {
                try SMAppService.mainApp.unregister()
            } else {
                try SMAppService.mainApp.register()
            }
        } catch {
            statusMenuItem.title = "Login item error — \(error.localizedDescription)"
        }
        refreshMenu()
    }
}
