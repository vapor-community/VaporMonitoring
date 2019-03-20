// swift-tools-version:4.0

import PackageDescription

let package = Package(
    name: "VaporMonitoring",
    products: [
        .library(name: "VaporMonitoring", targets: ["VaporMonitoring"])
    ],
    dependencies: [
        .package(url: "https://github.com/vapor/vapor.git", from: "3.1.0"),
        .package(url: "https://github.com/RuntimeTools/SwiftMetrics.git", from: "2.3.0"),
        .package(url: "https://github.com/MrLotU/SwiftPrometheus.git", from: "0.2.0")
    ],
    targets: [
      .target(name: "VaporMonitoring", dependencies: ["Vapor", "SwiftMetrics", "SwiftPrometheus"]),
      .target(name: "MonitoringExample", dependencies: ["VaporMonitoring"])
    ]
)
