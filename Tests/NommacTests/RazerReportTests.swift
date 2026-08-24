import Foundation
import Testing
@testable import Nommac

@Test func requestFramesCommandWithChecksum() {
    let report = RazerReport.request(commandClass: 0x07, commandID: 0x08, arguments: [0x00, 0x01])

    #expect(report.count == RazerReport.length)
    #expect(report[0] == RazerReport.reportID)
    #expect(report[2] == RazerReport.transactionID)
    #expect(report[6] == 2)
    #expect(report[7] == 0x07)
    #expect(report[8] == 0x08)
    #expect(Array(report[9 ..< 11]) == [0x00, 0x01])
    #expect(report[89] == RazerReport.checksum(of: report))
}

@Test func parseRoundTripsARequest() {
    var report = RazerReport.request(commandClass: 0x08, commandID: 0x84, arguments: [0x00, 0x0C, 0x18])
    report[1] = RazerReport.Status.success.rawValue

    let response = RazerReport.parse(report)

    #expect(response == RazerReport.Response(
        status: .success, commandClass: 0x08, commandID: 0x84, payload: [0x00, 0x0C, 0x18]
    ))
}

@Test func parseRejectsMalformedBuffers() {
    #expect(RazerReport.parse([]) == nil)
    #expect(RazerReport.parse([UInt8](repeating: 0, count: 42)) == nil)

    var wrongReportID = [UInt8](repeating: 0, count: RazerReport.length)
    wrongReportID[0] = 0x05
    #expect(RazerReport.parse(wrongReportID) == nil)
}

@Test func bandBytesMapToSignedDecibels() {
    let flat = Int(NommoDevice.flatBandByte)
    #expect(flat - 12 == 0x00)  // -12 dB floor
    #expect(flat + 12 == 0x18)  // +12 dB ceiling
}

@Test func presetTitlesCoverAllFirmwarePresets() {
    #expect(NommoPreset.allCases.map(\.rawValue) == [0, 1, 2, 3])
    #expect(NommoPreset.customRawValue == 0x10)
}
