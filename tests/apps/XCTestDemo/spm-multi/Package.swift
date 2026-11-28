// swift-tools-version: 6.0
// x86Sim: a Swift package with four test targets (x86sim test --spm): XCTest classes and Swift Testing tests whose
// names repeat across targets (SharedXCTests, shared(), Common/t()), a Swift Testing-only target (GammaTests, no
// `import XCTest`), a parameterized test failing on purpose and known issues (DeltaTests: withKnownIssue,
// XCTExpectFailure). check.sh runs selections on a phone and compares them with Apple's simulator (Xcode 27.2,
// xcodebuild test -only-testing / -skip-testing).
import PackageDescription

let package = Package(
    name: "Multi",
    platforms: [.iOS(.v17), .tvOS(.v17), .watchOS(.v10), .visionOS(.v1)],
    products: [.library(name: "Core", targets: ["Core"])],
    targets: [
        .target(name: "Core"),
        .testTarget(name: "AlphaTests", dependencies: ["Core"]),
        .testTarget(name: "BetaTests", dependencies: ["Core"]),
        .testTarget(name: "GammaTests", dependencies: ["Core"]),
        .testTarget(name: "DeltaTests", dependencies: ["Core"]),
    ]
)
