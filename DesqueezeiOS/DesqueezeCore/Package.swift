// swift-tools-version: 6.0
import PackageDescription

// Everything about Desqueeze that is not UIKit, Core Image or Vision. Kept free
// of Apple-only frameworks so the test suite runs anywhere Swift does.
let package = Package(
    name: "DesqueezeCore",
    platforms: [.iOS(.v18), .macOS(.v15)],
    products: [.library(name: "DesqueezeCore", targets: ["DesqueezeCore"])],
    targets: [
        .target(name: "DesqueezeCore"),
        .testTarget(name: "DesqueezeCoreTests", dependencies: ["DesqueezeCore"]),
    ]
)
