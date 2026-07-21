import Foundation

@MainActor
final class NommoController {
    enum State: Equatable {
        case inactive
        case active
        case failed(String)
    }

    private let monitor = DefaultOutputMonitor()
    private let attenuator = NommoAttenuator()
    private(set) var gainDecibels: Double
    private(set) var state: State = .inactive
    var onStateChange: (() -> Void)?

    init() {
        let saved = UserDefaults.standard.object(forKey: "gainDecibels") as? Double
        gainDecibels = saved ?? -24
    }

    func start() {
        do {
            try monitor.start { [weak self] in self?.reconcile() }
            reconcile()
        } catch {
            updateState(.failed(error.localizedDescription))
        }
    }

    func stop() {
        monitor.stop()
        attenuator.deactivate()
        updateState(.inactive)
    }

    func setGain(decibels: Double) {
        gainDecibels = decibels
        UserDefaults.standard.set(decibels, forKey: "gainDecibels")
        attenuator.setGain(decibels: decibels)
        onStateChange?()
    }

    private func reconcile() {
        guard shouldAttenuate(defaultOutputUID: monitor.currentUID()) else {
            attenuator.deactivate()
            updateState(.inactive)
            return
        }

        do {
            try attenuator.activate(decibels: gainDecibels)
            updateState(.active)
        } catch {
            updateState(.failed(error.localizedDescription))
        }
    }

    private func updateState(_ newState: State) {
        guard state != newState else { return }
        state = newState
        onStateChange?()
    }
}

