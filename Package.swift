// swift-tools-version: 5.9
import PackageDescription

let package = Package(
    name: "SwiftTE",
    platforms: [.macOS(.v12)],
    products: [
        .library(name: "TECore", targets: ["TECore"]),
        .library(name: "TEOP1", targets: ["TEOP1"]),
        .library(name: "TEOPXY", targets: ["TEOPXY"]),
    ],
    targets: [
        .target(name: "TECore"),
        .target(name: "TEOP1", dependencies: ["TECore"]),
        .target(name: "TEOPXY", dependencies: ["TECore"]),
        .testTarget(name: "TECoreTests", dependencies: ["TECore"]),
        .testTarget(name: "TEOP1Tests", dependencies: ["TEOP1"], resources: [.copy("Fixtures")]),
        .testTarget(name: "TEOPXYTests", dependencies: ["TEOPXY"]),
    ]
)
