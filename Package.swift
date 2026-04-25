// swift-tools-version: 5.9

import PackageDescription

let package = Package(
    name: "Clank",
    platforms: [
        .macOS(.v13)
    ],
    products: [
        .executable(name: "Clank", targets: ["Clank"])
    ],
    targets: [
        .executableTarget(
            name: "Clank",
            resources: [
                .copy("Resources/audio"),
                .copy("Resources/icon.png"),
                .copy("Resources/AppIcon.icns")
            ],
            linkerSettings: [
                .linkedFramework("AppKit"),
                .linkedFramework("AVFoundation"),
                .linkedFramework("IOKit")
            ]
        )
    ]
)
