// swift-tools-version: 6.0
import PackageDescription

// Two products, deliberately split.
//
// QuokkaEngine is pure Swift with no UIKit and no SwiftUI, so the parts worth being sure
// about -- URL canonicalisation, platform detection, the Instagram export parser -- run
// under `swift test` in a second, without a simulator.
//
// QuokkaDesign holds the tokens. It imports SwiftUI and cannot be tested that cheaply,
// which is exactly why no logic is allowed to live in it.
let package = Package(
    name: "QuokkaDesign",
    platforms: [.iOS(.v18), .macOS(.v14)],
    products: [
        .library(name: "QuokkaDesign", targets: ["QuokkaDesign"]),
        .library(name: "QuokkaEngine", targets: ["QuokkaEngine"]),
        .library(name: "QuokkaImaging", targets: ["QuokkaImaging"]),
    ],
    targets: [
        .target(name: "QuokkaDesign", dependencies: ["QuokkaEngine"]),
        .target(name: "QuokkaEngine"),
        .target(name: "QuokkaImaging"),
        .testTarget(name: "QuokkaEngineTests", dependencies: ["QuokkaEngine"]),
    ]
)
