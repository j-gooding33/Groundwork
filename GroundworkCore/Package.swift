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
        .testTarget(name: "GroundworkCoreTests", dependencies: ["GroundworkCore"]),
    ]
)
