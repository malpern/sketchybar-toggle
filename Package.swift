// swift-tools-version: 5.9

import PackageDescription

let package = Package(
    name: "sketchybar-toggle",
    platforms: [
        .macOS(.v13)
    ],
    targets: [
        .target(
            name: "SketchyBarToggleCore",
            path: "Sources/SketchyBarToggleCore"
        ),
        .executableTarget(
            name: "sketchybar-toggle",
            dependencies: ["SketchyBarToggleCore"],
            path: "Sources/SketchyBarToggle"
        ),
        .testTarget(
            name: "SketchyBarToggleTests",
            dependencies: ["SketchyBarToggleCore"],
            path: "Tests/SketchyBarToggleTests"
        )
    ]
)
