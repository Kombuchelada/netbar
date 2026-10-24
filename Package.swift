// swift-tools-version: 6.0
import PackageDescription

let package = Package(
    name: "Netbar",
    platforms: [.macOS(.v14)],
    targets: [
        .executableTarget(name: "Netbar"),
    ]
)
