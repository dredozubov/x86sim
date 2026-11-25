// swift-tools-version: 6.0

import PackageDescription

// The SwiftUI app around the Compose Multiplatform UI of ../shared. Frameworks/Shared.xcframework is
// linked on Linux by omarchy-apple-dev's kmp/build-framework.sh (kmp/build-app.sh puts it there).
let package = Package(
    name: "ComposeCounter",
    platforms: [
        .iOS(.v17),
    ],
    products: [
        .library(name: "ComposeCounter", targets: ["ComposeCounter"]),
    ],
    targets: [
        .binaryTarget(name: "Shared", path: "Frameworks/Shared.xcframework"),
        .target(name: "ComposeCounter", dependencies: ["Shared"]),
    ]
)
