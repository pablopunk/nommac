import Foundation

/// Razer 90-byte control protocol for the Nommo V2 X (1532:055E), carried in
/// HID feature reports on report ID 0x07. Reverse engineered in
/// https://github.com/openrazer/openrazer/issues/2758
enum RazerReport {
    static let reportID: UInt8 = 0x07
    static let transactionID: UInt8 = 0x3F
    static let length = 91  // report ID byte + 90-byte Razer report

    enum Status: UInt8 {
        case newCommand = 0x00
        case busy = 0x01
        case success = 0x02
        case failure = 0x03
        case timeout = 0x04
        case notSupported = 0x05
    }

    struct Response: Equatable {
        let status: Status
        let commandClass: UInt8
        let commandID: UInt8
        let payload: [UInt8]
    }

    static func request(commandClass: UInt8, commandID: UInt8, arguments: [UInt8]) -> [UInt8] {
        precondition(arguments.count <= 80)
        var buffer = [UInt8](repeating: 0, count: length)
        buffer[0] = reportID
        buffer[1] = Status.newCommand.rawValue
        buffer[2] = transactionID
        buffer[6] = UInt8(arguments.count)
        buffer[7] = commandClass
        buffer[8] = commandID
        buffer.replaceSubrange(9 ..< 9 + arguments.count, with: arguments)
        buffer[89] = checksum(of: buffer)
        return buffer
    }

    static func parse(_ bytes: [UInt8]) -> Response? {
        guard bytes.count == length, bytes[0] == reportID,
              let status = Status(rawValue: bytes[1])
        else { return nil }
        let payloadSize = min(Int(bytes[6]), 80)
        return Response(
            status: status,
            commandClass: bytes[7],
            commandID: bytes[8],
            payload: Array(bytes[9 ..< 9 + payloadSize])
        )
    }

    static func checksum(of buffer: [UInt8]) -> UInt8 {
        buffer[3 ..< 89].reduce(0, ^)
    }
}
