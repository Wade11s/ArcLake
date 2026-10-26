// swift-tools-version: 6.4
import PackageDescription

let package = Package(
    name: "ArcLakeM0",
    platforms: [.macOS(.v27)],
    products: [.executable(name: "ArcLakeM0", targets: ["ArcLakeM0"])],
    targets: [
        .target(name: "M0Core"),
        .executableTarget(name: "ArcLakeM0", dependencies: ["M0Core"]),
        .testTarget(name: "M0CoreTests", dependencies: ["M0Core"])
    ],
    swiftLanguageModes: [.v6]
)
