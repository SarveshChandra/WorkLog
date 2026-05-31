// swift-tools-version: 5.10

import PackageDescription

let package = Package(
    name: "WorkLog",
    platforms: [
        .macOS(.v13)
    ],
    products: [
        .executable(name: "WorkLog", targets: ["WorkLog"])
    ],
    targets: [
        .executableTarget(name: "WorkLog"),
        .testTarget(
            name: "WorkLogTests",
            dependencies: ["WorkLog"]
        )
    ]
)
