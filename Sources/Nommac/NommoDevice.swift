import Foundation
import IOKit.hid

struct NommoState: Equatable {
    var ecoEnabled: Bool
    var sleepTimeoutSeconds: Int
    var presetRawValue: UInt8
    var bandGainsDecibels: [Int]
}

enum NommoPreset: UInt8, CaseIterable, Identifiable {
    case flat = 0
    case game = 1
    case movie = 2
    case music = 3

    var id: UInt8 { rawValue }

    var title: String {
        switch self {
        case .flat: "Flat"
        case .game: "Game"
        case .movie: "Movie"
        case .music: "Music"
        }
    }

    static let customRawValue: UInt8 = 0x10
}

enum NommoDeviceError: Error {
    case disconnected
    case transportFailure(IOReturn)
    case commandRejected(RazerReport.Status)
    case malformedResponse
}

/// Owns the HID connection to the Nommo V2 X and serializes all Razer
/// feature-report transactions on a private queue.
final class NommoDevice: @unchecked Sendable {
    static let vendorID = 0x1532
    static let productID = 0x055E

    static let bandCount = 10
    static let bandLabels = ["31", "63", "125", "250", "500", "1k", "2k", "4k", "8k", "16k"]
    static let flatBandByte: UInt8 = 0x0C  // 0 dB, one unit per dB

    private let queue = DispatchQueue(label: "com.pablopunk.nommac.hid")
    private let manager: IOHIDManager
    private var device: IOHIDDevice?

    /// Called on the main actor whenever the speakers appear or disappear,
    /// and once with the current state when the handler is assigned.
    var onConnectionChange: (@MainActor @Sendable (Bool) -> Void)? {
        didSet {
            queue.async { self.notifyConnection(self.device != nil) }
        }
    }

    init() {
        manager = IOHIDManagerCreate(kCFAllocatorDefault, IOOptionBits(kIOHIDOptionsTypeNone))
        let matching: [String: Int] = [
            kIOHIDVendorIDKey: Self.vendorID,
            kIOHIDProductIDKey: Self.productID,
        ]
        IOHIDManagerSetDeviceMatching(manager, matching as CFDictionary)

        let context = Unmanaged.passUnretained(self).toOpaque()
        IOHIDManagerRegisterDeviceMatchingCallback(manager, { context, _, _, device in
            let self_ = Unmanaged<NommoDevice>.fromOpaque(context!).takeUnretainedValue()
            self_.deviceAppeared(device)
        }, context)
        IOHIDManagerRegisterDeviceRemovalCallback(manager, { context, _, _, device in
            let self_ = Unmanaged<NommoDevice>.fromOpaque(context!).takeUnretainedValue()
            self_.deviceDisappeared(device)
        }, context)

        IOHIDManagerSetDispatchQueue(manager, queue)
        IOHIDManagerOpen(manager, IOOptionBits(kIOHIDOptionsTypeNone))
        IOHIDManagerActivate(manager)
    }

    deinit {
        IOHIDManagerCancel(manager)
        IOHIDManagerClose(manager, IOOptionBits(kIOHIDOptionsTypeNone))
    }

    private func deviceAppeared(_ device: IOHIDDevice) {
        self.device = device
        notifyConnection(true)
    }

    private func deviceDisappeared(_ device: IOHIDDevice) {
        if self.device === device { self.device = nil }
        notifyConnection(self.device != nil)
    }

    private func notifyConnection(_ connected: Bool) {
        guard let onConnectionChange else { return }
        DispatchQueue.main.async {
            MainActor.assumeIsolated { onConnectionChange(connected) }
        }
    }

    // MARK: - Transactions

    private func transact(
        commandClass: UInt8, commandID: UInt8, arguments: [UInt8]
    ) throws -> [UInt8] {
        dispatchPrecondition(condition: .onQueue(queue))
        guard let device else { throw NommoDeviceError.disconnected }

        let request = RazerReport.request(
            commandClass: commandClass, commandID: commandID, arguments: arguments
        )
        let sendResult = request.withUnsafeBufferPointer {
            IOHIDDeviceSetReport(
                device, kIOHIDReportTypeFeature, CFIndex(RazerReport.reportID),
                $0.baseAddress!, $0.count
            )
        }
        guard sendResult == kIOReturnSuccess else {
            throw NommoDeviceError.transportFailure(sendResult)
        }

        usleep(60_000)

        var buffer = [UInt8](repeating: 0, count: RazerReport.length)
        buffer[0] = RazerReport.reportID
        var responseLength = CFIndex(RazerReport.length)
        let readResult = buffer.withUnsafeMutableBufferPointer {
            IOHIDDeviceGetReport(
                device, kIOHIDReportTypeFeature, CFIndex(RazerReport.reportID),
                $0.baseAddress!, &responseLength
            )
        }
        guard readResult == kIOReturnSuccess else {
            throw NommoDeviceError.transportFailure(readResult)
        }
        if responseLength == RazerReport.length - 1 {
            // The OS stripped the report ID byte; restore the codec's framing.
            buffer.insert(RazerReport.reportID, at: 0)
            buffer.removeLast()
        }
        guard let response = RazerReport.parse(buffer) else {
            throw NommoDeviceError.malformedResponse
        }
        guard response.status == .success else {
            throw NommoDeviceError.commandRejected(response.status)
        }
        return response.payload
    }

    /// Runs `work` with a synchronous transactor on the HID queue and delivers
    /// the result on the main queue.
    func perform<T: Sendable>(
        _ work: @escaping @Sendable (Transactor) throws -> T,
        completion: @escaping @MainActor @Sendable (Result<T, any Error>) -> Void
    ) {
        queue.async {
            let result: Result<T, any Error>
            do {
                result = .success(try work(Transactor(device: self)))
            } catch {
                result = .failure(error)
            }
            DispatchQueue.main.async {
                MainActor.assumeIsolated { completion(result) }
            }
        }
    }

    /// Runs `work` synchronously on the HID queue, looking the device up
    /// directly when the async matching callback has not fired yet (CLI use).
    func performBlocking<T>(_ work: (Transactor) throws -> T) throws -> T {
        try queue.sync {
            var attemptsLeft = 10
            while device == nil, attemptsLeft > 0 {
                device = (IOHIDManagerCopyDevices(manager) as? Set<IOHIDDevice>)?.first
                if device == nil {
                    attemptsLeft -= 1
                    usleep(50_000)
                }
            }
            return try work(Transactor(device: self))
        }
    }

    /// Synchronous typed commands, only valid inside `perform`.
    struct Transactor {
        fileprivate let device: NommoDevice

        private func run(_ cls: UInt8, _ cmd: UInt8, _ args: [UInt8]) throws -> [UInt8] {
            try device.transact(commandClass: cls, commandID: cmd, arguments: args)
        }

        func readState() throws -> NommoState {
            NommoState(
                ecoEnabled: try readEco(),
                sleepTimeoutSeconds: try readSleepTimeout(),
                presetRawValue: try run(0x08, 0x82, [0, 0])[1],
                bandGainsDecibels: try readBands()
            )
        }

        func readEco() throws -> Bool {
            try run(0x07, 0x88, [0, 0])[1] == 1
        }

        func setEco(_ enabled: Bool) throws {
            _ = try run(0x07, 0x08, [0, enabled ? 1 : 0])
        }

        func readSleepTimeout() throws -> Int {
            let payload = try run(0x07, 0x83, [0, 0])
            return Int(payload[0]) << 8 | Int(payload[1])
        }

        /// Firmware quirk: writing the timeout forces eco back on, so the eco
        /// flag is saved and restored around the write.
        func setSleepTimeout(seconds: Int) throws {
            let eco = try readEco()
            _ = try run(0x07, 0x03, [UInt8(seconds >> 8 & 0xFF), UInt8(seconds & 0xFF)])
            try setEco(eco)
        }

        func setPreset(_ preset: NommoPreset) throws {
            _ = try run(0x08, 0x02, [0, preset.rawValue])
        }

        func readBands() throws -> [Int] {
            let payload = try run(0x08, 0x84, [UInt8](repeating: 0, count: NommoDevice.bandCount + 1))
            return payload.dropFirst().map { Int($0) - Int(NommoDevice.flatBandByte) }
        }

        func setBands(_ gainsDecibels: [Int]) throws {
            let bytes = gainsDecibels.map {
                UInt8(clamping: $0 + Int(NommoDevice.flatBandByte))
            }
            _ = try run(0x08, 0x04, [0] + bytes)
        }
    }
}
