// swift-tools-version:5.10
import PackageDescription

let package = Package(
    name: "GroundworkCore",
    platforms: [.iOS(.v17), .macOS(.v14)],
    products: [
        .library(name: "GroundworkCore", targets: ["GroundworkCore"]),
    ],
    targets: [
        .target(name: "GroundworkCore"),
        // Timing check for big worlds: swift run -c release GroundworkBench
        // Not part of the library product, so the app never links it.
        .executableTarget(name: "GroundworkBench", dependencies: ["GroundworkCore"]),
        .testTarget(name: "GroundworkCoreTests", dependencies: ["GroundworkCore"]),
    ]
)
