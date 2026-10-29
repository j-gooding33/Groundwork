// swift-tools-version:5.10
import PackageDescription

let package = Package(
    name: "GroundworkCore",
    platforms: [.iOS(.v17), .macOS(.v14)],
    products: [
        .library(name: "GroundworkCore", targets: ["GroundworkCore"]),
        // What the app draws and how taps become commands. No Apple frameworks,
        // so it is tested on Linux; the iOS app is a thin layer over it.
        .library(name: "GroundworkView", targets: ["GroundworkView"]),
    ],
    targets: [
        .target(name: "GroundworkCore"),
        .target(name: "GroundworkView", dependencies: ["GroundworkCore"]),
        // Timing check for big worlds: swift run -c release GroundworkBench
        // Not part of the library products, so the app never links it.
        .executableTarget(name: "GroundworkBench", dependencies: ["GroundworkCore"]),
        // Renders screenshots of the real game to PNG: swift run GroundworkPreview
        .executableTarget(name: "GroundworkPreview", dependencies: ["GroundworkCore", "GroundworkView"]),
        .testTarget(name: "GroundworkCoreTests", dependencies: ["GroundworkCore"]),
        .testTarget(name: "GroundworkViewTests", dependencies: ["GroundworkCore", "GroundworkView"]),
    ]
)
