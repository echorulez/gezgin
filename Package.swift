// swift-tools-version:5.9
import PackageDescription

let package = Package(
    name: "Gezgin",
    platforms: [.macOS(.v14)],
    targets: [
        .executableTarget(
            name: "Gezgin",
            path: "Sources/Gezgin"
        )
    ]
)
