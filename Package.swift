// swift-tools-version:5.9
import PackageDescription

let package = Package(
    name: "Reel-AI",
    defaultLocalization: "en",
    platforms: [
        .iOS(.v16)
    ],
    dependencies: [
        .package(url: "https://github.com/appwrite/sdk-for-apple", from: "4.0.0")
    ],
    targets: [
        .executableTarget(
            name: "Reel-AI",
            dependencies: [
                .product(name: "Appwrite", package: "sdk-for-apple")
            ],
            path: "Reel-AI",
            resources: [
                .process("Preview Content"),
                .process("Assets.xcassets")
            ]
        ),
        .testTarget(
            name: "Reel-AITests",
            dependencies: ["Reel-AI"],
            path: "Reel-AITests"
        )
    ]
) 