// swift-tools-version: 5.9
import PackageDescription

let package = Package(
    name: "BambuserCalls-shopper",
    platforms: [
        .iOS(.v16),
    ],
    products: [
        // Primary library — what new dependents should pull in.
        .library(
            name: "BambuserCalls-shopper",
            targets: ["BambuserCallsShopper"]
        ),
    ],
    targets: [
        .target(
            name: "BambuserCallsShopper",
            path: "Sources/BambuserCallsShopper"
        ),
    ]
)
