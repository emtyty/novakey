// swift-tools-version: 5.9
import PackageDescription

let package = Package(
    name: "NovaKey",
    platforms: [
        .macOS(.v14)
    ],
    targets: [
        .executableTarget(
            name: "NovaKey",
            path: "Sources/NovaKey",
            linkerSettings: [
                .linkedFramework("Cocoa"),
                .linkedFramework("Carbon"),
            ]
        ),
    ]
)
