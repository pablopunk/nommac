import Foundation
import Observation
import ServiceManagement

@Observable
@MainActor
final class NommacModel {
    private let device = NommoDevice()

    private(set) var isConnected = false
    private(set) var isLaunchAtLoginEnabled = false
    private(set) var lastErrorDescription: String?

    var ecoEnabled = false
    var sleepTimeoutMinutes = 0
    var presetRawValue = NommoPreset.flat.rawValue
    var bandGainsDecibels = [Int](repeating: 0, count: NommoDevice.bandCount)

    private var pendingBandsWrite: DispatchWorkItem?

    var isCustomPreset: Bool {
        presetRawValue == NommoPreset.customRawValue
    }

    func start() {
        configureLaunchAtLoginOnce()
        device.onConnectionChange = { [weak self] connected in
            guard let self else { return }
            isConnected = connected
            if connected { refresh() }
        }
    }

    func refresh() {
        device.perform { transactor in
            try transactor.readState()
        } completion: { [weak self] result in
            guard let self else { return }
            switch result {
            case .success(let state):
                isConnected = true
                ecoEnabled = state.ecoEnabled
                sleepTimeoutMinutes = state.sleepTimeoutSeconds / 60
                presetRawValue = state.presetRawValue
                bandGainsDecibels = state.bandGainsDecibels
                lastErrorDescription = nil
            case .failure(let error):
                recordFailure(error)
            }
        }
    }

    func setEco(_ enabled: Bool) {
        ecoEnabled = enabled
        write { try $0.setEco(enabled) }
    }

    func setSleepTimeout(minutes: Int) {
        sleepTimeoutMinutes = minutes
        write { try $0.setSleepTimeout(seconds: minutes * 60) }
    }

    func selectPreset(_ preset: NommoPreset) {
        presetRawValue = preset.rawValue
        bandGainsDecibels = [Int](repeating: 0, count: NommoDevice.bandCount)
        write { try $0.setPreset(preset) }
    }

    /// App-side preset: every band at the −12 dB floor.
    func selectMinimumPreset() {
        presetRawValue = NommoPreset.customRawValue
        let gains = [Int](repeating: -12, count: NommoDevice.bandCount)
        bandGainsDecibels = gains
        write { try $0.setBands(gains) }
    }

    var isMinimumPreset: Bool {
        isCustomPreset && bandGainsDecibels.allSatisfy { $0 == -12 }
    }

    func setBandGain(index: Int, decibels: Int) {
        guard bandGainsDecibels.indices.contains(index) else { return }
        bandGainsDecibels[index] = decibels
        presetRawValue = NommoPreset.customRawValue
        let gains = bandGainsDecibels
        debounce(&pendingBandsWrite) { [self] in
            write { try $0.setBands(gains) }
        }
    }

    func setLaunchAtLogin(_ enabled: Bool) {
        do {
            if enabled {
                try SMAppService.mainApp.register()
            } else {
                try SMAppService.mainApp.unregister()
            }
        } catch {
            lastErrorDescription = error.localizedDescription
        }
        synchronizeLaunchAtLoginState()
    }

    private func write(_ work: @escaping @Sendable (NommoDevice.Transactor) throws -> Void) {
        device.perform(work) { [weak self] result in
            if case .failure(let error) = result {
                self?.recordFailure(error)
            }
        }
    }

    private func debounce(_ pending: inout DispatchWorkItem?, action: @escaping () -> Void) {
        pending?.cancel()
        let workItem = DispatchWorkItem(block: action)
        pending = workItem
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.08, execute: workItem)
    }

    private func recordFailure(_ error: Error) {
        if case NommoDeviceError.disconnected = error {
            isConnected = false
            return
        }
        lastErrorDescription = String(describing: error)
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

    private func synchronizeLaunchAtLoginState() {
        isLaunchAtLoginEnabled = SMAppService.mainApp.status == .enabled
    }
}
