// swift-tools-version:4.0

import PackageDescription

let package = Package(
    name: "VaporMonitoring",
    products: [
        .library(name: "VaporMonitoring", targets: ["VaporMonitoring"])
    ],
    dependencies: [
        .package(url: "https://github.com/vapor/vapor.git", from: "3.0.5"),
        // Using my own fork here to avoid downloading Kitura files that we wont need
        // You can use the original branch too, the only thing that's different
        // Is that it includes Kitura specefic packages/code
        .package(url: "https://github.com/RuntimeTools/SwiftMetrics.git", from: "2.3.0"),
        .package(url: "https://github.com/vapor/leaf.git", from: "3.0.0-rc")
    ],
    targets: [
      .target(name: "VaporMonitoring", dependencies: ["Vapor", "SwiftMetrics", "Leaf"]),
      .target(name: "MonitoringTests", dependencies: ["VaporMonitoring"])
    ]
)
