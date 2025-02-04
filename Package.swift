// swift-tools-version:5.9
import PackageDescription

let package = Package(
    name: "Reel-AI",
    defaultLocalization: "en",
    platforms: [
        .iOS(.v16)
    ],
    dependencies: [
        .package(url: "https://github.com/appwrite/sdk-for-apple", from: "4.0.0"),
        .package(url: "https://github.com/muxinc/mux-stats-sdk-avplayer.git", from: "3.1.0"),
        .package(url: "https://github.com/Flight-School/AnyCodable", from: "0.6.7"),
    ],
    targets: [
        .executableTarget(
            name: "Reel-AI",
            dependencies: [
                .product(name: "Appwrite", package: "sdk-for-apple"),
                .product(name: "MUXSDKStats", package: "mux-stats-sdk-avplayer")
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