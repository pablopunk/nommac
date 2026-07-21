// swift-tools-version: 6.0
import PackageDescription

let package = Package(
    name: "NommoNight",
    platforms: [.macOS(.v15)],
    products: [.executable(name: "NommoNight", targets: ["NommoNight"])],
    targets: [
        .executableTarget(name: "NommoNight", swiftSettings: [.swiftLanguageMode(.v5)]),
        .testTarget(name: "NommoNightTests", dependencies: ["NommoNight"])
    ]
)
