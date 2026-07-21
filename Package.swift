// swift-tools-version: 6.0
import PackageDescription

let package = Package(
    name: "Nommac",
    platforms: [.macOS(.v15)],
    products: [.executable(name: "Nommac", targets: ["Nommac"])],
    targets: [
        .executableTarget(name: "Nommac", swiftSettings: [.swiftLanguageMode(.v5)]),
        .testTarget(name: "NommacTests", dependencies: ["Nommac"])
    ]
)
