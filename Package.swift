// swift-tools-version: 6.4
import PackageDescription

let package = Package(
  name: "ArcLake",
  platforms: [.macOS(.v27)],
  products: [
    .executable(name: "ArcLakeM0", targets: ["ArcLakeM0"]),
    .executable(name: "ArcLakeM1", targets: ["ArcLakeM1"]),
    .library(name: "ArcLakeCore", targets: ["ArcLakeCore"]),
    .library(name: "ArcLakePersistence", targets: ["ArcLakePersistence"]),
  ],
  targets: [
    .target(name: "M0Core"),
    .executableTarget(name: "ArcLakeM0", dependencies: ["M0Core"]),
    .target(name: "ArcLakeCore"),
    .target(
      name: "ArcLakePersistence", dependencies: ["ArcLakeCore"],
      linkerSettings: [.linkedLibrary("sqlite3")]),
    .executableTarget(
      name: "ArcLakeM1",
      dependencies: ["ArcLakeCore", "ArcLakePersistence"],
      swiftSettings: [.defaultIsolation(MainActor.self)]
    ),
    .testTarget(name: "M0CoreTests", dependencies: ["M0Core"]),
    .testTarget(name: "ArcLakeCoreTests", dependencies: ["ArcLakeCore"]),
    .testTarget(
      name: "ArcLakePersistenceTests", dependencies: ["ArcLakeCore", "ArcLakePersistence"]),
  ],
  swiftLanguageModes: [.v6]
)
