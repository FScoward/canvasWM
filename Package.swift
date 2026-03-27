// swift-tools-version: 6.0

import PackageDescription

let package = Package(
    name: "CanvasWM",
    platforms: [
        .macOS(.v14)
    ],
    targets: [
        .target(
            name: "CanvasWMLib",
            path: "Sources/CanvasWMLib",
            swiftSettings: [
                .swiftLanguageMode(.v5)
            ]
        ),
        .executableTarget(
            name: "CanvasWM",
            dependencies: ["CanvasWMLib"],
            path: "Sources/CanvasWM",
            swiftSettings: [
                .swiftLanguageMode(.v5)
            ]
        ),
        .executableTarget(
            name: "CanvasWMTests",
            dependencies: ["CanvasWMLib"],
            path: "Tests/CanvasWMTests",
            swiftSettings: [
                .swiftLanguageMode(.v5)
            ]
        )
    ]
)
