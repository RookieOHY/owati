// swift-tools-version: 5.9
import PackageDescription

let package = Package(
    name: "owati",
    platforms: [
        .macOS(.v14)
    ],
    targets: [
        .executableTarget(
            name: "owati",
            path: "Sources/owati"
        )
    ]
)
