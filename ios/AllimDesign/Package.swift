// swift-tools-version: 6.0
import PackageDescription

// Two products, deliberately split.
//
// AllimEngine is pure Swift with no UIKit and no SwiftUI, so the parts worth being sure
// about -- URL canonicalisation, platform detection, the Instagram export parser -- run
// under `swift test` in a second, without a simulator.
//
// AllimDesign holds the tokens. It imports SwiftUI and cannot be tested that cheaply,
// which is exactly why no logic is allowed to live in it.
let package = Package(
    name: "AllimDesign",
    platforms: [.iOS(.v18), .macOS(.v14)],
    products: [
        .library(name: "AllimDesign", targets: ["AllimDesign"]),
        .library(name: "AllimEngine", targets: ["AllimEngine"]),
    ],
    targets: [
        .target(name: "AllimDesign", dependencies: ["AllimEngine"]),
        .target(name: "AllimEngine"),
        .testTarget(name: "AllimEngineTests", dependencies: ["AllimEngine"]),
    ]
)
