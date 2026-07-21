import AudioToolbox
import Foundation
import Synchronization

@MainActor
final class OutputAttenuator {
    private var tapID = AudioObjectID(kAudioObjectUnknown)
    private var aggregateID = AudioObjectID(kAudioObjectUnknown)
    private var ioProcID: AudioDeviceIOProcID?
    private var tapDescription: CATapDescription?
    private let queue = DispatchQueue(label: "Nommac.Audio", qos: .userInitiated)
    private let targetGainBits = Atomic<UInt32>(Float(1).bitPattern)
    private nonisolated(unsafe) var currentGain: Float = 1
    private var activeOutput: AudioOutput?

    var isActive: Bool {
        tapID != kAudioObjectUnknown && aggregateID != kAudioObjectUnknown
    }

    func setGain(decibels: Double) {
        targetGainBits.store(amplitude(forDecibels: decibels).bitPattern, ordering: .relaxed)
    }

    func activate(output: AudioOutput, decibels: Double) throws {
        if isActive, activeOutput == output {
            setGain(decibels: decibels)
            return
        }
        deactivate()

        let initialGain = amplitude(forDecibels: decibels)
        targetGainBits.store(initialGain.bitPattern, ordering: .relaxed)
        currentGain = initialGain

        let stream = try output.id.firstOutputStreamIndex()
        let process = try AudioObjectID.currentProcessObject()
        let tap = CATapDescription(processes: [process], deviceUID: output.uid, stream: stream)
        tap.uuid = UUID()
        tap.isExclusive = true
        tap.muteBehavior = .mutedWhenTapped
        tap.isPrivate = true

        var createdTap = AudioObjectID(kAudioObjectUnknown)
        var status = AudioHardwareCreateProcessTap(tap, &createdTap)
        guard status == noErr else { throw CoreAudioError(status) }
        tapID = createdTap
        tapDescription = tap
        activeOutput = output

        let description: [String: Any] = [
            kAudioAggregateDeviceNameKey: "Nommac – \(output.name)",
            kAudioAggregateDeviceUIDKey: "com.pablopunk.nommac.aggregate.\(UUID().uuidString)",
            kAudioAggregateDeviceMainSubDeviceKey: output.uid,
            kAudioAggregateDeviceClockDeviceKey: output.uid,
            kAudioAggregateDeviceIsPrivateKey: true,
            kAudioAggregateDeviceIsStackedKey: true,
            kAudioAggregateDeviceTapAutoStartKey: true,
            kAudioAggregateDeviceSubDeviceListKey: [[
                kAudioSubDeviceUIDKey: output.uid,
                kAudioSubDeviceDriftCompensationKey: false
            ]],
            kAudioAggregateDeviceTapListKey: [[
                kAudioSubTapDriftCompensationKey: true,
                kAudioSubTapUIDKey: tap.uuid.uuidString
            ]]
        ]

        var createdAggregate = AudioObjectID(kAudioObjectUnknown)
        status = AudioHardwareCreateAggregateDevice(description as CFDictionary, &createdAggregate)
        guard status == noErr else {
            deactivate()
            throw CoreAudioError(status)
        }
        aggregateID = createdAggregate

        guard waitUntilReady() else {
            deactivate()
            throw CoreAudioError(kAudioHardwareUnspecifiedError)
        }

        status = AudioDeviceCreateIOProcIDWithBlock(&ioProcID, aggregateID, queue) { [weak self] _, input, _, output, _ in
            guard let self else {
                Self.clear(output)
                return
            }
            self.process(input: input, output: output)
        }
        guard status == noErr else {
            deactivate()
            throw CoreAudioError(status)
        }

        status = AudioDeviceStart(aggregateID, ioProcID)
        guard status == noErr else {
            deactivate()
            throw CoreAudioError(status)
        }
    }

    func deactivate() {
        if aggregateID != kAudioObjectUnknown, let ioProcID {
            AudioDeviceStop(aggregateID, ioProcID)
            AudioDeviceDestroyIOProcID(aggregateID, ioProcID)
        }
        ioProcID = nil

        if aggregateID != kAudioObjectUnknown {
            AudioHardwareDestroyAggregateDevice(aggregateID)
        }
        aggregateID = kAudioObjectUnknown

        if tapID != kAudioObjectUnknown {
            AudioHardwareDestroyProcessTap(tapID)
        }
        tapID = kAudioObjectUnknown
        tapDescription = nil
        activeOutput = nil
    }

    private func waitUntilReady() -> Bool {
        let deadline = Date().addingTimeInterval(2)
        while Date() < deadline {
            if aggregateID.outputStreamCount() > 0 { return true }
            RunLoop.current.run(until: Date().addingTimeInterval(0.02))
        }
        return false
    }

    private nonisolated func process(
        input: UnsafePointer<AudioBufferList>,
        output: UnsafeMutablePointer<AudioBufferList>
    ) {
        let inputs = UnsafeMutableAudioBufferListPointer(UnsafeMutablePointer(mutating: input))
        let outputs = UnsafeMutableAudioBufferListPointer(output)
        let targetGain = Float(bitPattern: targetGainBits.load(ordering: .relaxed))

        for outputIndex in outputs.indices {
            let inputIndex = inputs.count > outputs.count
                ? inputs.count - outputs.count + outputIndex
                : outputIndex
            guard inputIndex < inputs.count,
                  let inputData = inputs[inputIndex].mData,
                  let outputData = outputs[outputIndex].mData else {
                Self.clear(outputs[outputIndex])
                continue
            }

            let inputSamples = inputData.assumingMemoryBound(to: Float.self)
            let outputSamples = outputData.assumingMemoryBound(to: Float.self)
            let inputCount = Int(inputs[inputIndex].mDataByteSize) / MemoryLayout<Float>.size
            let outputCount = Int(outputs[outputIndex].mDataByteSize) / MemoryLayout<Float>.size
            let count = min(inputCount, outputCount)

            for sample in 0..<count {
                currentGain += (targetGain - currentGain) * 0.0007
                outputSamples[sample] = inputSamples[sample] * currentGain
            }
            if count < outputCount {
                memset(outputSamples.advanced(by: count), 0, (outputCount - count) * MemoryLayout<Float>.size)
            }
        }
    }

    private nonisolated static func clear(_ list: UnsafeMutablePointer<AudioBufferList>) {
        for buffer in UnsafeMutableAudioBufferListPointer(list) {
            clear(buffer)
        }
    }

    private nonisolated static func clear(_ buffer: AudioBuffer) {
        if let data = buffer.mData {
            memset(data, 0, Int(buffer.mDataByteSize))
        }
    }
}
