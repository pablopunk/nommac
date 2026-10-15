import Foundation
import Testing
@testable import Nommac

private let flatBands = [Int](repeating: 0, count: NommoDevice.bandCount)

private func deviceState(preset: UInt8, bands: [Int]) -> NommoState {
    NommoState(
        ecoEnabled: false, sleepTimeoutSeconds: 0,
        presetRawValue: preset, bandGainsDecibels: bands
    )
}

private func custom(_ gains: [Int]) -> NommoEQSelection {
    NommoEQSelection(presetRawValue: NommoPreset.customRawValue, bandGainsDecibels: gains)
}

/// Storage that lives only for the test, so nothing is written to the real
/// preferences directory.
private final class InMemoryStorage: EQStorage {
    private var values: [String: Data] = [:]

    func storedData(forKey key: String) -> Data? { values[key] }

    func setStoredData(_ data: Data?, forKey key: String) { values[key] = data }
}

@Test func customCurveIsRestoredOnlyWhenItDiffers() {
    let curve = [4, 3, 2, 0, 0, 0, 0, 1, 2, 3]
    let selection = custom(curve)

    #expect(!selection.needsRestoring(
        given: deviceState(preset: NommoPreset.customRawValue, bands: curve)
    ))
    // What the speakers report once they have been switched off and on.
    #expect(selection.needsRestoring(
        given: deviceState(preset: NommoPreset.flat.rawValue, bands: flatBands)
    ))
    // Right curve, but the firmware no longer flags it as custom.
    #expect(selection.needsRestoring(
        given: deviceState(preset: NommoPreset.flat.rawValue, bands: curve)
    ))
    #expect(selection.needsRestoring(
        given: deviceState(preset: NommoPreset.customRawValue, bands: flatBands)
    ))
}

@Test func namedPresetIsAlwaysReasserted() {
    let movie = NommoEQSelection(
        presetRawValue: NommoPreset.movie.rawValue, bandGainsDecibels: flatBands
    )

    // What a Nommo V2 X actually reports after being switched off and on: a
    // stale preset number with flat bands, indistinguishable by reading from
    // the preset being properly applied. Reasserting is the only safe move.
    #expect(movie.needsRestoring(
        given: deviceState(preset: NommoPreset.movie.rawValue, bands: flatBands)
    ))
    #expect(movie.needsRestoring(
        given: deviceState(preset: NommoPreset.movie.rawValue, bands: [3, 2, 0, 0, 0, 0, 0, 0, 2, 4])
    ))
    #expect(movie.needsRestoring(
        given: deviceState(preset: NommoPreset.flat.rawValue, bands: flatBands)
    ))
}

@Test func onlyTenInRangeGainsAreWellFormed() {
    #expect(custom(flatBands).isWellFormed)
    #expect(custom([-12, 12, 0, 0, 0, 0, 0, 0, 0, 0]).isWellFormed)
    #expect(!custom([Int](repeating: 0, count: NommoDevice.bandCount - 1)).isWellFormed)
    #expect(!custom([Int](repeating: 0, count: NommoDevice.bandCount + 1)).isWellFormed)
    #expect(!custom([13, 0, 0, 0, 0, 0, 0, 0, 0, 0]).isWellFormed)
    #expect(!custom([-13, 0, 0, 0, 0, 0, 0, 0, 0, 0]).isWellFormed)
}

@Test func storeRoundTripsTheUsersChoice() {
    let store = EQStore(storage: InMemoryStorage())
    #expect(store.selection == nil)

    let curve = [2, 2, 1, 0, 0, 0, 0, 0, -1, -2]
    store.store(presetRawValue: NommoPreset.customRawValue, bandGainsDecibels: curve)
    #expect(store.selection == custom(curve))

    store.store(presetRawValue: NommoPreset.game.rawValue, bandGainsDecibels: flatBands)
    #expect(store.selection?.presetRawValue == NommoPreset.game.rawValue)
}

@Test func storeRefusesAChoiceItCouldNotApply() {
    let store = EQStore(storage: InMemoryStorage())
    store.store(presetRawValue: NommoPreset.customRawValue, bandGainsDecibels: [0, 0])
    #expect(store.selection == nil)

    store.store(
        presetRawValue: NommoPreset.customRawValue,
        bandGainsDecibels: [99] + [Int](repeating: 0, count: NommoDevice.bandCount - 1)
    )
    #expect(store.selection == nil)
}

@Test func storeIgnoresValuesItDidNotWrite() {
    let storage = InMemoryStorage()

    // Eight bands, as an older build or a hand-edited plist might hold.
    storage.setStoredData(
        Data(#"{"presetRawValue":16,"bandGainsDecibels":[0,0,0,0,0,0,0,0]}"#.utf8),
        forKey: EQStore.defaultsKey
    )
    #expect(EQStore(storage: storage).selection == nil)

    storage.setStoredData(Data("not json at all".utf8), forKey: EQStore.defaultsKey)
    #expect(EQStore(storage: storage).selection == nil)
}

@Test func storeDiscardsTheChoiceWhenCleared() {
    let storage = InMemoryStorage()
    let store = EQStore(storage: storage)
    store.store(presetRawValue: NommoPreset.customRawValue, bandGainsDecibels: flatBands)
    #expect(store.selection != nil)

    store.selection = nil
    #expect(store.selection == nil)
    #expect(storage.storedData(forKey: EQStore.defaultsKey) == nil)
}

/// Pins the stored format: renaming the coding keys would silently drop
/// everyone's stored EQ, so the on-disk shape is part of the contract.
@Test func storeReadsTheDocumentedOnDiskShape() {
    let storage = InMemoryStorage()
    storage.setStoredData(
        Data(#"{"presetRawValue":16,"bandGainsDecibels":[-7,-7,-7,-7,-7,-7,-7,-7,-7,-7]}"#.utf8),
        forKey: EQStore.defaultsKey
    )
    #expect(
        EQStore(storage: storage).selection
            == custom([Int](repeating: -7, count: NommoDevice.bandCount))
    )
}
