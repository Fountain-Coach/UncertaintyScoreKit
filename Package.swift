// swift-tools-version: 6.1
import PackageDescription

// UncertaintyScoreKit — a provider-independent map of what a first pass is unsure of, rendered as an orchestra of
// dimensions over a spine. Functional Core / Imperative Shell:
//   · UncertaintyScoreKit    — the FUNCTIONAL CORE: pure value types + projections, no I/O, no UI, no dependencies.
//   · UncertaintyScoreKitUI  — the IMPERATIVE SHELL: SwiftUI rendering, mixer, validated encodings.
//   · UncertaintyScoreDemo   — the SHELL's snapshot harness: renders the fixture scores to PNG for pixel review.
let package = Package(
    name: "UncertaintyScoreKit",
    platforms: [
        .macOS(.v14)
    ],
    products: [
        .library(name: "UncertaintyScoreKit", targets: ["UncertaintyScoreKit"]),
        .library(name: "UncertaintyScoreKitUI", targets: ["UncertaintyScoreKitUI"]),
        .executable(name: "UncertaintyScoreDemo", targets: ["UncertaintyScoreDemo"])
    ],
    targets: [
        .target(
            name: "UncertaintyScoreKit"
        ),
        .target(
            name: "UncertaintyScoreKitUI",
            dependencies: ["UncertaintyScoreKit"]
        ),
        .executableTarget(
            name: "UncertaintyScoreDemo",
            dependencies: ["UncertaintyScoreKit", "UncertaintyScoreKitUI"]
        ),
        .testTarget(
            name: "UncertaintyScoreKitTests",
            dependencies: ["UncertaintyScoreKit"]
        )
    ]
)
