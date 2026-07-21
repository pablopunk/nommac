import Foundation
import Testing
@testable import Nommac

@Test func decibelsConvertToAmplitude() {
    #expect(abs(amplitude(forDecibels: -6) - 0.501187) < 0.00001)
    #expect(abs(amplitude(forDecibels: -24) - 0.063096) < 0.00001)
}

@Test func zeroDecibelsBypassesAudioProcessing() {
    #expect(shouldAttenuate(gainDecibels: -1))
    #expect(!shouldAttenuate(gainDecibels: 0))
}

@Test func gainIsClampedToSliderRange() {
    #expect(clampedGainDecibels(-80) == -48)
    #expect(clampedGainDecibels(-24) == -24)
    #expect(clampedGainDecibels(8) == 0)
}

@Test func gainProfilesAreIndependentByOutput() {
    let suite = "NommacTests.\(UUID().uuidString)"
    let defaults = UserDefaults(suiteName: suite)!
    defer { defaults.removePersistentDomain(forName: suite) }
    let profiles = GainProfileStore(defaults: defaults, legacyDefaults: nil)

    profiles.setGain(-24, for: "speakers")
    profiles.setGain(-8, for: "headphones")

    #expect(profiles.gain(for: "speakers") == -24)
    #expect(profiles.gain(for: "headphones") == -8)
    #expect(profiles.gain(for: "new-output") == 0)
}

@Test func clearingMigratedNommoGainStaysCleared() {
    let suite = "NommacTests.\(UUID().uuidString)"
    let defaults = UserDefaults(suiteName: suite)!
    defer { defaults.removePersistentDomain(forName: suite) }
    defaults.set(-24.0, forKey: "gainDecibels")

    let migrated = GainProfileStore(defaults: defaults, legacyDefaults: nil)
    #expect(migrated.gain(for: legacyNommoDeviceUID) == -24)
    migrated.setGain(0, for: legacyNommoDeviceUID)

    let relaunched = GainProfileStore(defaults: defaults, legacyDefaults: nil)
    #expect(relaunched.gain(for: legacyNommoDeviceUID) == 0)
}
