import Testing
@testable import Nommac

@Test func decibelsConvertToAmplitude() {
    #expect(abs(amplitude(forDecibels: -6) - 0.501187) < 0.00001)
    #expect(abs(amplitude(forDecibels: -24) - 0.063096) < 0.00001)
}

@Test func processingOnlyTargetsNommo() {
    #expect(shouldAttenuate(defaultOutputUID: nommoDeviceUID))
    #expect(!shouldAttenuate(defaultOutputUID: "AirPods"))
    #expect(!shouldAttenuate(defaultOutputUID: nil))
}

@Test func gainIsClampedToSliderRange() {
    #expect(clampedGainDecibels(-80) == -48)
    #expect(clampedGainDecibels(-24) == -24)
    #expect(clampedGainDecibels(8) == 0)
}
