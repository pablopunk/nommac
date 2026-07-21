import AudioToolbox

@MainActor
final class DefaultOutputMonitor {
    private var listener: AudioObjectPropertyListenerBlock?
    private var onChange: (() -> Void)?
    private var address = AudioObjectPropertyAddress(
        mSelector: kAudioHardwarePropertyDefaultOutputDevice,
        mScope: kAudioObjectPropertyScopeGlobal,
        mElement: kAudioObjectPropertyElementMain
    )

    func start(onChange: @escaping () -> Void) throws {
        guard listener == nil else { return }
        self.onChange = onChange
        let block: AudioObjectPropertyListenerBlock = { [weak self] _, _ in
            MainActor.assumeIsolated {
                self?.onChange?()
            }
        }
        let status = AudioObjectAddPropertyListenerBlock(AudioObjectID(kAudioObjectSystemObject), &address, .main, block)
        guard status == noErr else { throw CoreAudioError(status) }
        listener = block
    }

    func stop() {
        if let listener {
            AudioObjectRemovePropertyListenerBlock(AudioObjectID(kAudioObjectSystemObject), &address, .main, listener)
        }
        listener = nil
        onChange = nil
    }

    func currentUID() -> String? {
        try? AudioObjectID.defaultOutputDevice().uid()
    }
}
