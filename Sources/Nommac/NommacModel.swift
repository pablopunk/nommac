import Foundation
import Observation
import ServiceManagement

@Observable
@MainActor
final class NommacModel {
    private let device = NommoDevice()
    private let eqStore = EQStore()

    private(set) var isConnected = false
    private(set) var isLaunchAtLoginEnabled = false
    private(set) var lastErrorDescription: String?

    var ecoEnabled = false
    var sleepTimeoutMinutes = 0
    var presetRawValue = NommoPreset.flat.rawValue
    var bandGainsDecibels = [Int](repeating: 0, count: NommoDevice.bandCount)

    private var pendingBandsWrite: DispatchWorkItem?
    private var groupDragBaseline: [Int]?

    var isCustomPreset: Bool {
        presetRawValue == NommoPreset.customRawValue
    }

    func start() {
        configureLaunchAtLoginOnce()
        device.onConnectionChange = { [weak self] connected in
            guard let self else { return }
            isConnected = connected
            if connected { restoreAndRefresh() }
        }
    }

    /// Reads the device state into the UI without writing to the speakers.
    func refresh() {
        read(retriesLeft: 2, restoring: nil)
    }

    /// The speakers have just appeared, which means the firmware has dropped
    /// the EQ: write the stored choice back, then read what they ended up
    /// with. This is the only path that restores.
    private func restoreAndRefresh() {
        read(retriesLeft: 2, restoring: eqStore.selection)
    }

    /// The HID interface can appear a moment before the firmware will answer
    /// feature reports, and that is exactly when the EQ needs restoring, so a
    /// transport failure here is retried before it is reported.
    private func read(retriesLeft: Int, restoring stored: NommoEQSelection?) {
        device.perform { transactor in
            try transactor.readState(restoring: stored)
        } completion: { [weak self] result in
            guard let self else { return }
            switch result {
            case .success(let state):
                publish(state)
            case .failure(let error):
                if retriesLeft > 0, case NommoDeviceError.transportFailure = error {
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.4) { [weak self] in
                        self?.read(retriesLeft: retriesLeft - 1, restoring: stored)
                    }
                } else {
                    recordFailure(error)
                }
            }
        }
    }

    private func publish(_ state: NommoState) {
        isConnected = true
        ecoEnabled = state.ecoEnabled
        sleepTimeoutMinutes = state.sleepTimeoutSeconds / 60
        presetRawValue = state.presetRawValue
        bandGainsDecibels = state.bandGainsDecibels
        lastErrorDescription = nil
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
        storeEQSelection()
        write { try $0.setPreset(preset) }
    }

    /// App-side preset: every band at the −12 dB floor.
    func selectMinimumPreset() {
        presetRawValue = NommoPreset.customRawValue
        let gains = [Int](
            repeating: NommoDevice.gainRange.lowerBound, count: NommoDevice.bandCount
        )
        bandGainsDecibels = gains
        storeEQSelection()
        write { try $0.setBands(gains) }
    }

    var isMinimumPreset: Bool {
        isCustomPreset && bandGainsDecibels.allSatisfy { $0 == NommoDevice.gainRange.lowerBound }
    }

    func setBandGain(index: Int, decibels: Int) {
        guard bandGainsDecibels.indices.contains(index) else { return }
        bandGainsDecibels[index] = decibels
        presetRawValue = NommoPreset.customRawValue
        storeEQSelection()
        let gains = bandGainsDecibels
        debounce(&pendingBandsWrite) { [self] in
            write { try $0.setBands(gains) }
        }
    }

    /// Cmd+drag on any band: shifts every band by the same delta from where
    /// the drag started, each clamped independently so bands already at the
    /// EQ floor/ceiling simply stop rather than dragging the rest off course.
    func beginGroupEQDrag() {
        groupDragBaseline = bandGainsDecibels
    }

    func applyGroupEQDrag(deltaDecibels: Int) {
        guard let groupDragBaseline else { return }
        presetRawValue = NommoPreset.customRawValue
        let gains = groupDragBaseline.map {
            ($0 + deltaDecibels).clamped(to: NommoDevice.gainRange)
        }
        bandGainsDecibels = gains
        storeEQSelection()
        debounce(&pendingBandsWrite) { [self] in
            write { try $0.setBands(gains) }
        }
    }

    func endGroupEQDrag() {
        groupDragBaseline = nil
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

    /// Stores the user's EQ choice immediately, before the debounced write,
    /// so a restore running in the meantime can't revert it.
    private func storeEQSelection() {
        eqStore.store(
            presetRawValue: presetRawValue, bandGainsDecibels: bandGainsDecibels
        )
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
