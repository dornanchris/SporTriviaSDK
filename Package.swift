// swift-tools-version: 5.9
import PackageDescription

let package = Package(
    name: "SporTriviaSDK",
    platforms: [.iOS(.v16)],
    products: [
        .library(name: "SporTriviaSDK", targets: ["SporTriviaSDK"])
    ],
    targets: [
        .target(name: "SporTriviaSDK", path: "Sources/SporTriviaSDK"),
        .testTarget(name: "SporTriviaSDKTests", dependencies: ["SporTriviaSDK"])
    ]
)
