import Foundation

@MainActor
final class OutputController {
    enum State: Equatable {
        case bypassed
        case active
        case failed(String)
    }

    private let monitor = DefaultOutputMonitor()
    private let attenuator = OutputAttenuator()
    private let profiles = GainProfileStore()
    private(set) var output: AudioOutput?
    private(set) var gainDecibels = 0.0
    private(set) var state: State = .bypassed
    var onStateChange: (() -> Void)?

    func start() {
        do {
            try monitor.start { [weak self] in self?.reconcileOutput() }
            reconcileOutput()
        } catch {
            fail(error)
        }
    }

    func stop() {
        monitor.stop()
        attenuator.deactivate()
        state = .bypassed
        onStateChange?()
    }

    func setGain(decibels: Double) {
        guard let output else { return }
        gainDecibels = clampedGainDecibels(decibels)
        profiles.setGain(gainDecibels, for: output.uid)
        applyGain(to: output)
    }

    private func reconcileOutput() {
        do {
            let currentOutput = try monitor.currentOutput()
            if output != currentOutput {
                attenuator.deactivate()
            }
            output = currentOutput
            gainDecibels = profiles.gain(for: currentOutput.uid)
            applyGain(to: currentOutput)
        } catch {
            output = nil
            gainDecibels = 0
            attenuator.deactivate()
            fail(error)
        }
    }

    private func applyGain(to output: AudioOutput) {
        do {
            if shouldAttenuate(gainDecibels: gainDecibels) {
                try attenuator.activate(output: output, decibels: gainDecibels)
                state = .active
            } else {
                attenuator.deactivate()
                state = .bypassed
            }
            onStateChange?()
        } catch {
            attenuator.deactivate()
            fail(error)
        }
    }

    private func fail(_ error: Error) {
        state = .failed(error.localizedDescription)
        onStateChange?()
    }
}
