// swift-tools-version:4.0

import PackageDescription

let package = Package(
    name: "VaporMonitoring",
    products: [
        .library(name: "VaporMonitoring", targets: ["VaporMonitoring"])
    ],
    dependencies: [
        .package(url: "https://github.com/MrLotU/vapor.git", .branch("master")),
        .package(url: "https://github.com/MrLotU/SwiftMetrics.git", .branch("master")),
        .package(url: "https://github.com/vapor/leaf.git", .branch("master"))
    ],
    targets: [
      .target(name: "VaporMonitoring", dependencies: ["Vapor", "SwiftMetrics", "Leaf"]),
      .target(name: "MonitoringTests", dependencies: ["VaporMonitoring"])
    ]
)
