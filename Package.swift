// swift-tools-version:5.9
import PackageDescription

let package = Package(
    name: "Cadence",
    platforms: [.macOS(.v13)],
    targets: [
        .target(name: "CadenceCore"),
        .executableTarget(name: "Cadence", dependencies: ["CadenceCore"]),
        .testTarget(name: "CadenceCoreTests", dependencies: ["CadenceCore"]),
    ]
)
