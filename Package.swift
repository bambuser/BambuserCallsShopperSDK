// swift-tools-version: 5.9
import PackageDescription

let package = Package(
    name: "BambuserCalls-shopper",
    platforms: [
        .iOS(.v16),
    ],
    products: [
        .library(
            name: "BambuserCalls-shopper",
            targets: ["BambuserCallsShopper"]
        ),
    ],
    targets: [
        .binaryTarget(
            name: "BambuserCallsShopper",
            path: "Framework/BambuserCallsShopper.xcframework"
        ),
    ]
)
