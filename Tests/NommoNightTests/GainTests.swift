import Testing
@testable import NommoNight

@Test func decibelsConvertToAmplitude() {
    #expect(abs(amplitude(forDecibels: -6) - 0.501187) < 0.00001)
    #expect(abs(amplitude(forDecibels: -24) - 0.063096) < 0.00001)
}

@Test func processingOnlyTargetsNommo() {
    #expect(shouldAttenuate(defaultOutputUID: nommoDeviceUID))
    #expect(!shouldAttenuate(defaultOutputUID: "AirPods"))
    #expect(!shouldAttenuate(defaultOutputUID: nil))
}

