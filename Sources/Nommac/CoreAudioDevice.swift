import AudioToolbox
import CoreFoundation

extension AudioObjectID {
    static func currentProcessObject() throws -> AudioObjectID {
        var address = AudioObjectPropertyAddress(
            mSelector: kAudioHardwarePropertyTranslatePIDToProcessObject,
            mScope: kAudioObjectPropertyScopeGlobal,
            mElement: kAudioObjectPropertyElementMain
        )
        var pid = getpid()
        var process = AudioObjectID(kAudioObjectUnknown)
        var size = UInt32(MemoryLayout<AudioObjectID>.size)
        let status = withUnsafePointer(to: &pid) {
            AudioObjectGetPropertyData(
                AudioObjectID(kAudioObjectSystemObject),
                &address,
                UInt32(MemoryLayout<pid_t>.size),
                $0,
                &size,
                &process
            )
        }
        guard status == noErr else { throw CoreAudioError(status) }
        return process
    }

    static func defaultOutputDevice() throws -> AudioObjectID {
        var address = AudioObjectPropertyAddress(
            mSelector: kAudioHardwarePropertyDefaultOutputDevice,
            mScope: kAudioObjectPropertyScopeGlobal,
            mElement: kAudioObjectPropertyElementMain
        )
        var device = AudioObjectID(kAudioObjectUnknown)
        var size = UInt32(MemoryLayout<AudioObjectID>.size)
        let status = AudioObjectGetPropertyData(AudioObjectID(kAudioObjectSystemObject), &address, 0, nil, &size, &device)
        guard status == noErr else { throw CoreAudioError(status) }
        return device
    }

    func uid() throws -> String {
        var address = AudioObjectPropertyAddress(
            mSelector: kAudioDevicePropertyDeviceUID,
            mScope: kAudioObjectPropertyScopeGlobal,
            mElement: kAudioObjectPropertyElementMain
        )
        var value: CFString = "" as CFString
        var size = UInt32(MemoryLayout<CFString>.size)
        let status = withUnsafeMutablePointer(to: &value) {
            AudioObjectGetPropertyData(self, &address, 0, nil, &size, $0)
        }
        guard status == noErr else { throw CoreAudioError(status) }
        return value as String
    }

    func name() throws -> String {
        var address = AudioObjectPropertyAddress(
            mSelector: kAudioObjectPropertyName,
            mScope: kAudioObjectPropertyScopeGlobal,
            mElement: kAudioObjectPropertyElementMain
        )
        var value: CFString = "" as CFString
        var size = UInt32(MemoryLayout<CFString>.size)
        let status = withUnsafeMutablePointer(to: &value) {
            AudioObjectGetPropertyData(self, &address, 0, nil, &size, $0)
        }
        guard status == noErr else { throw CoreAudioError(status) }
        return value as String
    }

    func audioOutput() throws -> AudioOutput {
        AudioOutput(id: self, uid: try uid(), name: try name())
    }

    func outputStreamCount() -> Int {
        var address = AudioObjectPropertyAddress(
            mSelector: kAudioDevicePropertyStreams,
            mScope: kAudioObjectPropertyScopeOutput,
            mElement: kAudioObjectPropertyElementMain
        )
        var size: UInt32 = 0
        guard AudioObjectGetPropertyDataSize(self, &address, 0, nil, &size) == noErr else { return 0 }
        return Int(size) / MemoryLayout<AudioStreamID>.size
    }

    func firstOutputStreamIndex() throws -> UInt {
        let streams = try streamIDs(scope: kAudioObjectPropertyScopeGlobal)
        for (index, stream) in streams.enumerated() {
            var address = AudioObjectPropertyAddress(
                mSelector: kAudioStreamPropertyDirection,
                mScope: kAudioObjectPropertyScopeGlobal,
                mElement: kAudioObjectPropertyElementMain
            )
            var direction: UInt32 = 1
            var size = UInt32(MemoryLayout<UInt32>.size)
            if AudioObjectGetPropertyData(stream, &address, 0, nil, &size, &direction) == noErr,
               direction == 0 {
                return UInt(index)
            }
        }

        guard outputStreamCount() > 0 else { throw CoreAudioError(kAudioHardwareBadDeviceError) }
        return 0
    }

    private func streamIDs(scope: AudioObjectPropertyScope) throws -> [AudioStreamID] {
        var address = AudioObjectPropertyAddress(
            mSelector: kAudioDevicePropertyStreams,
            mScope: scope,
            mElement: kAudioObjectPropertyElementMain
        )
        var size: UInt32 = 0
        var status = AudioObjectGetPropertyDataSize(self, &address, 0, nil, &size)
        guard status == noErr else { throw CoreAudioError(status) }

        var streams = [AudioStreamID](
            repeating: kAudioObjectUnknown,
            count: Int(size) / MemoryLayout<AudioStreamID>.size
        )
        status = AudioObjectGetPropertyData(self, &address, 0, nil, &size, &streams)
        guard status == noErr else { throw CoreAudioError(status) }
        return streams
    }
}

struct CoreAudioError: LocalizedError {
    let status: OSStatus

    init(_ status: OSStatus) {
        self.status = status
    }

    var errorDescription: String? {
        "CoreAudio error \(status)"
    }
}
