// swift-tools-version:4.2
// The swift-tools-version declares the minimum version of Swift required to build this package.

import PackageDescription

let package = Package(
    name: "Taan",
    dependencies: [
      .package(url: "https://github.com/raheelahmad/Down", .branch("master")),
      .package(url: "https://github.com/vapor/Leaf", from: "3.0.2"),
      .package(url: "https://github.com/apple/swift-package-manager.git", from: "0.3.0")
    ],
    targets: [
        .target(
            name: "Taan",
            dependencies: ["TaanCore"]),
        .target(
            name: "TaanCore",
            dependencies: ["Down", "Leaf", "Utility"]),
    ]
)
