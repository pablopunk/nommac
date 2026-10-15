import Foundation
import Testing
@testable import Nommac

@Test func gainsParseFromTenValuesOrOneRepeated() throws {
    #expect(try NommacCLI.parseGains(["3"]) == [Int](repeating: 3, count: 10))
    #expect(
        try NommacCLI.parseGains(["-12", "-9", "0", "1", "2", "3", "4", "5", "6", "12"])
            == [-12, -9, 0, 1, 2, 3, 4, 5, 6, 12]
    )
}

@Test func gainsRejectWrongCountAndRange() {
    #expect(throws: NommacCLI.CLIError.self) { try NommacCLI.parseGains(["1", "2"]) }
    #expect(throws: NommacCLI.CLIError.self) { try NommacCLI.parseGains(["13"]) }
    #expect(throws: NommacCLI.CLIError.self) { try NommacCLI.parseGains(["bass"]) }
}

@Test func onOffParsesCommonSpellings() throws {
    #expect(try NommacCLI.parseOnOff("on"))
    #expect(try NommacCLI.parseOnOff("1"))
    #expect(!(try NommacCLI.parseOnOff("off")))
    #expect(throws: NommacCLI.CLIError.self) { _ = try NommacCLI.parseOnOff("maybe") }
}

@Test func onlyBareEQForgetSkipsTheDevice() {
    #expect(NommacCLI.isForgetCommand("eq", ["forget"]))
    // Anything else must take the normal path, so a typo cannot silently
    // clear the stored curve instead of being reported as an error.
    #expect(!NommacCLI.isForgetCommand("eq", ["forget", "3"]))
    #expect(!NommacCLI.isForgetCommand("eq", ["show"]))
    #expect(!NommacCLI.isForgetCommand("eq", []))
    #expect(!NommacCLI.isForgetCommand("preset", ["forget"]))
}
