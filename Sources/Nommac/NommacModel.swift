import Foundation
import Observation
import ServiceManagement

@Observable
@MainActor
final class NommacModel {
    private let controller = NommoController()
    private(set) var gainDecibels: Double
    private(set) var state: NommoController.State = .inactive
    private(set) var isLaunchAtLoginEnabled = false

    init() {
        gainDecibels = controller.gainDecibels
    }

    var statusTitle: String {
        switch state {
        case .inactive: "Waiting for Nommo"
        case .active: "Razer Nommo V2 X"
        case .failed: "Audio unavailable"
        }
    }

    var statusSymbol: String {
        switch state {
        case .inactive: "speaker.slash"
        case .active: "speaker.wave.1.fill"
        case .failed: "exclamationmark.triangle"
        }
    }

    func start() {
        configureLaunchAtLoginOnce()
        controller.onStateChange = { [weak self] in self?.synchronizeControllerState() }
        controller.start()
        synchronizeControllerState()
    }

    func stop() {
        controller.stop()
    }

    func setGain(_ decibels: Double) {
        let value = clampedGainDecibels(decibels).rounded()
        guard value != gainDecibels else { return }
        gainDecibels = value
        controller.setGain(decibels: value)
    }

    func setLaunchAtLogin(_ enabled: Bool) {
        do {
            if enabled {
                try SMAppService.mainApp.register()
            } else {
                try SMAppService.mainApp.unregister()
            }
        } catch {
            state = .failed(error.localizedDescription)
        }
        synchronizeLaunchAtLoginState()
    }

    private func configureLaunchAtLoginOnce() {
        let key = "didConfigureLaunchAtLogin"
        guard !UserDefaults.standard.bool(forKey: key) else {
            synchronizeLaunchAtLoginState()
            return
        }

        if SMAppService.mainApp.status != .enabled {
            try? SMAppService.mainApp.register()
        }
        UserDefaults.standard.set(true, forKey: key)
        synchronizeLaunchAtLoginState()
    }

    private func synchronizeControllerState() {
        gainDecibels = controller.gainDecibels
        state = controller.state
    }

    private func synchronizeLaunchAtLoginState() {
        isLaunchAtLoginEnabled = SMAppService.mainApp.status == .enabled
    }
}
