// swift-tools-version:4.0

import PackageDescription

let package = Package(
    name: "VaporMonitoring",
    products: [
        .library(name: "VaporMonitoring", targets: ["VaporMonitoring"])
    ],
    dependencies: [
        .package(url: "https://github.com/MrLotU/vapor.git", .branch("master")),
        // Using my own fork here to avoid downloading Kitura files that we wont need
        // You can use the original branch too, the only thing that's different
        // Is that it includes Kitura specefic packages/code
        .package(url: "https://github.com/MrLotU/SwiftMetrics.git", .branch("master")),
        .package(url: "https://github.com/vapor/leaf.git", .branch("master"))
    ],
    targets: [
      .target(name: "VaporMonitoring", dependencies: ["Vapor", "SwiftMetrics", "Leaf"]),
      .target(name: "MonitoringTests", dependencies: ["VaporMonitoring"])
    ]
)
