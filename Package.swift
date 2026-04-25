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
                .copy("Resources/audio")
            ],
            linkerSettings: [
                .linkedFramework("AppKit"),
                .linkedFramework("AVFoundation"),
                .linkedFramework("IOKit")
            ]
        ),
        .testTarget(
            name: "ClankTests",
            dependencies: ["Clank"]
        )
    ]
)
