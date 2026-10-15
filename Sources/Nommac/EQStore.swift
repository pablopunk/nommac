import Foundation

/// The slice of `UserDefaults` that `EQStore` needs. Injecting it keeps the
/// tests out of the real preferences directory.
protocol EQStorage: AnyObject {
    func storedData(forKey key: String) -> Data?
    func setStoredData(_ data: Data?, forKey key: String)
}

extension UserDefaults: EQStorage {
    func storedData(forKey key: String) -> Data? { data(forKey: key) }

    func setStoredData(_ data: Data?, forKey key: String) {
        if let data {
            set(data, forKey: key)
        } else {
            removeObject(forKey: key)
        }
    }
}

/// Stores the EQ the user chose, so it can be written back after the
/// speakers power-cycle and forget it.
///
/// This stores the user's *intent*, and only ever records a deliberate choice.
/// It must never record what was read from the device: speakers that have just
/// been switched back on report a flat EQ, and saving that would quietly
/// overwrite the curve we are trying to restore. The device therefore stays the
/// source of truth for what is applied right now — this is only a record of
/// what to ask for again.
struct EQStore {
    /// An explicit domain shared by the menu-bar app and the CLI. The CLI runs
    /// from `Contents/Resources` inside the bundle, where `Bundle.main` does
    /// not resolve to the app, so `UserDefaults.standard` would hand the two
    /// processes different domains and the CLI could not see what the app
    /// stored.
    static let suiteName = "com.pablopunk.nommac.shared"
    static let defaultsKey = "storedEQSelection"

    static var sharedDefaults: UserDefaults {
        UserDefaults(suiteName: suiteName) ?? .standard
    }

    private let storage: any EQStorage

    init(storage: any EQStorage = EQStore.sharedDefaults) {
        self.storage = storage
    }

    /// The stored choice, or nil when the user has not made one yet or the
    /// stored value cannot be trusted.
    var selection: NommoEQSelection? {
        get {
            guard let data = storage.storedData(forKey: Self.defaultsKey),
                  let selection = try? JSONDecoder().decode(NommoEQSelection.self, from: data),
                  selection.isWellFormed
            else { return nil }
            return selection
        }
        nonmutating set {
            guard let newValue, newValue.isWellFormed,
                  let data = try? JSONEncoder().encode(newValue)
            else {
                storage.setStoredData(nil, forKey: Self.defaultsKey)
                return
            }
            storage.setStoredData(data, forKey: Self.defaultsKey)
        }
    }

    func store(presetRawValue: UInt8, bandGainsDecibels: [Int]) {
        selection = NommoEQSelection(
            presetRawValue: presetRawValue, bandGainsDecibels: bandGainsDecibels
        )
    }
}
