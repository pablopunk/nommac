import AppKit
import ServiceManagement

@MainActor
final class AppDelegate: NSObject, NSApplicationDelegate {
    private let controller = NommoController()
    private let statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
    private let statusMenuItem = NSMenuItem(title: "Starting…", action: nil, keyEquivalent: "")
    private let launchAtLoginItem = NSMenuItem(title: "Launch at Login", action: #selector(toggleLaunchAtLogin), keyEquivalent: "")
    private lazy var sliderView = GainSliderView(value: controller.gainDecibels) { [weak self] decibels in
        self?.controller.setGain(decibels: decibels)
    }

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
        statusItem.button?.toolTip = "Nommac"

        let menu = NSMenu()
        menu.autoenablesItems = false
        statusMenuItem.isEnabled = false
        menu.addItem(statusMenuItem)

        let sliderItem = NSMenuItem()
        sliderItem.view = sliderView
        menu.addItem(sliderItem)
        menu.addItem(.separator())

        launchAtLoginItem.target = self
        launchAtLoginItem.isEnabled = true
        menu.addItem(launchAtLoginItem)

        let quitItem = NSMenuItem(title: "Quit Nommac", action: #selector(NSApplication.terminate(_:)), keyEquivalent: "q")
        quitItem.isEnabled = true
        menu.addItem(quitItem)
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
            statusMenuItem.title = "Login item unavailable"
        }
    }

    private func refreshMenu() {
        sliderView.setValue(controller.gainDecibels)
        launchAtLoginItem.state = SMAppService.mainApp.status == .enabled ? .on : .off

        switch controller.state {
        case .inactive:
            statusMenuItem.title = "Waiting for Nommo"
            setStatusIcon("speaker.slash", description: "Nommac idle")
        case .active:
            statusMenuItem.title = "Nommo · \(Int(controller.gainDecibels)) dB"
            setStatusIcon("speaker.wave.1.fill", description: "Nommac active")
        case .failed:
            statusMenuItem.title = "Audio unavailable"
            setStatusIcon("exclamationmark.triangle", description: "Nommac error")
        }
    }

    private func setStatusIcon(_ symbol: String, description: String) {
        statusItem.button?.image = NSImage(systemSymbolName: symbol, accessibilityDescription: description)
    }

    @objc private func toggleLaunchAtLogin() {
        do {
            if SMAppService.mainApp.status == .enabled {
                try SMAppService.mainApp.unregister()
            } else {
                try SMAppService.mainApp.register()
            }
        } catch {
            statusMenuItem.title = "Login item unavailable"
        }
        refreshMenu()
    }
}
