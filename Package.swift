// swift-tools-version: 5.9
import PackageDescription

let package = Package(
    name: "AROK",
    platforms: [
        .macOS(.v14)
    ],
    products: [
        .executable(
            name: "AROK",
            targets: ["AROK"]
        ),
    ],
    dependencies: [
        // System monitoring - we'll use native APIs
    ],
    targets: [
        .executableTarget(
            name: "AROK",
            dependencies: [],
            path: "Sources"
        ),
    ]
)
