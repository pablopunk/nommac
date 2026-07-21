import Foundation

let nommoDeviceUID = "AppleUSBAudioEngine:Actions:Razer Nommo V2 X:000000000000000:2"
let gainDecibelRange = -48.0...0.0

func amplitude(forDecibels decibels: Double) -> Float {
    Float(pow(10, decibels / 20))
}

func clampedGainDecibels(_ decibels: Double) -> Double {
    min(max(decibels, gainDecibelRange.lowerBound), gainDecibelRange.upperBound)
}

func shouldAttenuate(defaultOutputUID: String?) -> Bool {
    defaultOutputUID == nommoDeviceUID
}
