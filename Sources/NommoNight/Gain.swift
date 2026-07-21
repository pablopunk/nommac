import Foundation

let nommoDeviceUID = "AppleUSBAudioEngine:Actions:Razer Nommo V2 X:000000000000000:2"

func amplitude(forDecibels decibels: Double) -> Float {
    Float(pow(10, decibels / 20))
}

func shouldAttenuate(defaultOutputUID: String?) -> Bool {
    defaultOutputUID == nommoDeviceUID
}

