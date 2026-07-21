import Foundation

final class GainProfileStore {
    private let defaults: UserDefaults
    private let legacyDefaults: UserDefaults?
    private let profilesKey = "gainProfiles"
    private let migrationKey = "didMigrateGainProfiles"

    init(
        defaults: UserDefaults = .standard,
        legacyDefaults: UserDefaults? = UserDefaults(suiteName: "com.pablopunk.NommoNight")
    ) {
        self.defaults = defaults
        self.legacyDefaults = legacyDefaults
        migrateNommoGainIfNeeded()
    }

    func gain(for outputUID: String) -> Double {
        clampedGainDecibels(profiles[outputUID] ?? 0)
    }

    func setGain(_ decibels: Double, for outputUID: String) {
        var updated = profiles
        let gain = clampedGainDecibels(decibels)
        if gain == 0 {
            updated.removeValue(forKey: outputUID)
        } else {
            updated[outputUID] = gain
        }
        defaults.set(updated, forKey: profilesKey)
    }

    private var profiles: [String: Double] {
        defaults.dictionary(forKey: profilesKey)?.compactMapValues { value in
            (value as? NSNumber)?.doubleValue
        } ?? [:]
    }

    private func migrateNommoGainIfNeeded() {
        guard !defaults.bool(forKey: migrationKey) else { return }
        defaults.set(true, forKey: migrationKey)
        guard profiles[legacyNommoDeviceUID] == nil else { return }
        let saved = defaults.object(forKey: "gainDecibels") as? Double
        let legacy = legacyDefaults?.object(forKey: "gainDecibels") as? Double
        guard let gain = saved ?? legacy else { return }
        setGain(gain, for: legacyNommoDeviceUID)
    }
}
