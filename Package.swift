// swift-tools-version:5.9
import PackageDescription

let package = Package(
    name: "Clip",
    platforms: [.macOS(.v14)],
    targets: [.executableTarget(name: "Clip", path: "Sources/Clip")]
)
