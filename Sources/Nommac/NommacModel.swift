import Foundation
import Observation
import ServiceManagement

@Observable
@MainActor
final class NommacModel {
    private let controller = OutputController()
    private(set) var gainDecibels: Double
    private(set) var state: OutputController.State = .bypassed
    private(set) var outputName: String?
    private(set) var isLaunchAtLoginEnabled = false

    init() {
        gainDecibels = 0
    }

    var statusTitle: String {
        switch state {
        case .bypassed, .active: outputName ?? "Waiting for output"
        case .failed: "Audio unavailable"
        }
    }

    var statusSymbol: String {
        switch state {
        case .bypassed: outputName == nil ? "speaker.slash" : "speaker.wave.2"
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
        outputName = controller.output?.name
    }

    private func synchronizeLaunchAtLoginState() {
        isLaunchAtLoginEnabled = SMAppService.mainApp.status == .enabled
    }
}
