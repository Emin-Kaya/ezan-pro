// swift-tools-version:5.9
import PackageDescription

let package = Package(
    name: "EzanPro",
    platforms: [.macOS(.v14)],
    targets: [
        .executableTarget(name: "EzanPro", path: "Sources/EzanPro")
    ]
)
