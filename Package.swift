// swift-tools-version:5.9
import PackageDescription

let package = Package(
    name: "MissionControl",
    platforms: [
        .macOS(.v14)
    ],
    products: [
        .executable(name: "MissionControl", targets: ["MissionControl"])
    ],
    targets: [
        .executableTarget(
            name: "MissionControl",
            path: "Sources/MissionControl"
        )
    ]
)
