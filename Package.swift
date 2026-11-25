// swift-tools-version:5.9
import PackageDescription

let package = Package(
    name: "Pomo",
    platforms: [.macOS(.v13)],
    targets: [
        .target(name: "PomoCore"),
        .executableTarget(name: "Pomo", dependencies: ["PomoCore"]),
        .testTarget(name: "PomoCoreTests", dependencies: ["PomoCore"]),
    ]
)
