// swift-tools-version:5.9

import PackageDescription

let package = Package(
    name: "BlockerKit",
    platforms: [
        .iOS(.v16),
        .macOS(.v13),
    ],
    products: [
        // Tiny, dependency-free module linked by the Safari extensions.
        .library(name: "BlockerShared", targets: ["BlockerShared"]),
        // Download + conversion pipeline, linked by the app only.
        .library(name: "BlockerKit", targets: ["BlockerKit"]),
    ],
    dependencies: [
        .package(url: "https://github.com/AdguardTeam/SafariConverterLib.git", exact: "4.3.1"),
    ],
    targets: [
        .target(name: "BlockerShared"),
        .target(
            name: "BlockerKit",
            dependencies: [
                "BlockerShared",
                .product(name: "ContentBlockerConverter", package: "SafariConverterLib"),
            ]
        ),
        .testTarget(name: "BlockerKitTests", dependencies: ["BlockerKit"]),
    ]
)
