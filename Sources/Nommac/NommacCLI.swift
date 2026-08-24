import Foundation

/// Headless command-line mode: `nommac <command>` talks to the speakers and
/// exits without touching the menu-bar UI.
enum NommacCLI {
    static let usage = """
    usage: nommac <command> [args]

    commands:
      status                     show all settings
      eco [on|off]               get/set power saving (auto sleep)
      sleep [<minutes>|off]      get/set idle sleep timeout
      eq [show|flat|min|<g1..g10>]
                                 get/set 10-band EQ gains in dB (-12..12)
                                 min puts every band at the -12 dB floor
      preset [flat|game|movie|music|0-3]
                                 get/set EQ preset (resets bands to flat)
      volume [0-100]             get/set master volume

    run with no arguments outside a terminal to start the menu-bar app
    """

    static func run(_ arguments: [String]) -> Int32 {
        guard let command = arguments.first, !["-h", "--help", "help"].contains(command) else {
            print(usage)
            return arguments.isEmpty ? 1 : 0
        }
        do {
            try dispatch(command: command, arguments: Array(arguments.dropFirst()))
            return 0
        } catch let error as CLIError {
            FileHandle.standardError.write(Data("error: \(error.message)\n".utf8))
            return 1
        } catch {
            FileHandle.standardError.write(Data("error: \(error)\n".utf8))
            return 1
        }
    }

    struct CLIError: Error {
        let message: String
    }

    private static func dispatch(command: String, arguments: [String]) throws {
        let device = NommoDevice()
        try device.performBlocking { transactor in
            switch command {
            case "status": try printStatus(transactor)
            case "eco": try runEco(transactor, arguments)
            case "sleep": try runSleep(transactor, arguments)
            case "eq": try runEQ(transactor, arguments)
            case "preset": try runPreset(transactor, arguments)
            case "volume": try runVolume(transactor, arguments)
            default: throw CLIError(message: "unknown command '\(command)'\n\n\(usage)")
            }
        }
    }

    private static func printStatus(_ transactor: NommoDevice.Transactor) throws {
        let state = try transactor.readState()
        let timeout = state.sleepTimeoutSeconds > 0
            ? "\(state.sleepTimeoutSeconds / 60) min" : "disabled"
        print("eco (power saving): \(state.ecoEnabled ? "on" : "off")")
        print("sleep timeout:      \(timeout)")
        print("volume:             \(state.volume)")
        print("eq preset:          \(presetName(state.presetRawValue)) (\(state.presetRawValue))")
        print("eq bands (dB):")
        print("  " + NommoDevice.bandLabels.map { pad($0) }.joined(separator: "  "))
        print("  " + state.bandGainsDecibels.map { pad(formatGain($0)) }.joined(separator: "  "))
    }

    private static func runEco(_ transactor: NommoDevice.Transactor, _ arguments: [String]) throws {
        guard let argument = arguments.first else {
            print(try transactor.readEco() ? "on" : "off")
            return
        }
        let enabled = try parseOnOff(argument)
        try transactor.setEco(enabled)
        print("eco \(enabled ? "on" : "off")")
    }

    private static func runSleep(_ transactor: NommoDevice.Transactor, _ arguments: [String]) throws {
        guard let argument = arguments.first else {
            let seconds = try transactor.readSleepTimeout()
            print(seconds > 0 ? "\(seconds / 60) min" : "disabled")
            return
        }
        let minutes: Int
        if ["off", "never", "0"].contains(argument) {
            minutes = 0
        } else if let parsed = Int(argument), (0 ... 1092).contains(parsed) {
            minutes = parsed
        } else {
            throw CLIError(message: "minutes must be 0-1092 or off")
        }
        try transactor.setSleepTimeout(seconds: minutes * 60)
        print(minutes > 0 ? "sleep timeout set to \(minutes) min" : "sleep disabled")
    }

    private static func runEQ(_ transactor: NommoDevice.Transactor, _ arguments: [String]) throws {
        if arguments.isEmpty || arguments == ["show"] {
            print(try transactor.readBands().map(formatGain).joined(separator: " "))
            return
        }
        let gains: [Int]
        switch arguments {
        case ["flat"]: gains = [Int](repeating: 0, count: NommoDevice.bandCount)
        case ["min"]: gains = [Int](repeating: -12, count: NommoDevice.bandCount)
        default: gains = try parseGains(arguments)
        }
        try transactor.setBands(gains)
        print("eq set: " + gains.map(formatGain).joined(separator: " "))
    }

    private static func runPreset(_ transactor: NommoDevice.Transactor, _ arguments: [String]) throws {
        guard let argument = arguments.first else {
            let raw = try transactor.readState().presetRawValue
            print("\(presetName(raw)) (\(raw))")
            return
        }
        let preset = NommoPreset.allCases.first {
            $0.title.lowercased() == argument || String($0.rawValue) == argument
        }
        guard let preset else {
            throw CLIError(message: "preset must be flat/game/movie/music or 0-3")
        }
        try transactor.setPreset(preset)
        print("preset set to \(preset.title.lowercased()) (\(preset.rawValue))")
    }

    private static func runVolume(_ transactor: NommoDevice.Transactor, _ arguments: [String]) throws {
        guard let argument = arguments.first else {
            print(try transactor.readState().volume)
            return
        }
        guard let volume = Int(argument), (0 ... 100).contains(volume) else {
            throw CLIError(message: "volume must be 0-100")
        }
        try transactor.setVolume(volume)
        print("volume set to \(volume)")
    }

    static func parseGains(_ arguments: [String]) throws -> [Int] {
        var values = arguments
        if values.count == 1 {
            values = [String](repeating: values[0], count: NommoDevice.bandCount)
        }
        guard values.count == NommoDevice.bandCount else {
            throw CLIError(message: "expected \(NommoDevice.bandCount) band gains, got \(values.count)")
        }
        return try values.map {
            guard let gain = Int($0), (-12 ... 12).contains(gain) else {
                throw CLIError(message: "gain '\($0)' out of range -12..12 dB")
            }
            return gain
        }
    }

    static func parseOnOff(_ value: String) throws -> Bool {
        switch value {
        case "on", "1", "true": return true
        case "off", "0", "false": return false
        default: throw CLIError(message: "expected on/off, got '\(value)'")
        }
    }

    private static func presetName(_ raw: UInt8) -> String {
        if raw == NommoPreset.customRawValue { return "custom" }
        return NommoPreset(rawValue: raw)?.title.lowercased() ?? "\(raw)"
    }

    private static func formatGain(_ gain: Int) -> String {
        gain > 0 ? "+\(gain)" : "\(gain)"
    }

    private static func pad(_ text: String) -> String {
        String(repeating: " ", count: max(0, 4 - text.count)) + text
    }
}
