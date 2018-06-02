# VaporMonitoring
[![Vapor 3](https://img.shields.io/badge/vapor-3.0-blue.svg?style=flat)](https://vapor.codes)
[![Swift 4.1](https://img.shields.io/badge/swift-4.2-orange.svg?style=flat)](http://swift.org)

##

`VaporMonitoring` is a Vapor 3 package for monitoring and providing metrics for your Vapor application. Built on top op [SwiftMetrics](https://github.com/RuntimeTools/SwiftMetrics). Vapor Monitoring provides the default SwiftMetrics metrics along with request specific metrics. Metrics can be viewed using the provided dashboard or using Prometheus. 

## Installation
Vapor Monitoring can be installed using SPM
```swift
.package(url: "https://github.com/MrLotU/VaporMonitoring.git", from: 0.0.1)
```

## Usage
Vapor Monitoring is easy to use, it requires only a few lines of code.

Vapor Monitoring requires a few things to work correclty, a `MonitoredRouter` and a `MonitoredResponder` are the most important ones.

To set up your monitoring, in your `Configure.swift` file, add the following: 
```swift
let router = try VaporMonitoring.setupMonitoring(&config, &services)
services.register(router, as: Router.self)
```
***_Note:_*** \
This currently also sets up a middlewareConfig to use with the dashboard \
If you need your own middleware, for now you have to disable the dashboard in the MonitorConfig

***_Note if using dashboard_*** \
If you want to use the dashboard, in your `boot.swift` add the following inside your `boot(_:)` function:
```swift
_ = try app.make(VaporMetricsDash.self)
```

What this does is load VaporMonitoring with the default configuration. This includes adding all required services to your apps services & setting some configuration prefferences to use the `MonitoredResponder` and `MonitoredRouter`.

By default, your dashboard will be served at `host:port/metrics` and your prometheus metrics will be served at `host:port/prometheus-metrics`. You can however customize this, as well as turning the dashboard/prometheus dashboard on or off. This also creates a HTTPServer running a WebSocketServer to power the dashboard.

To customize your monitoring, add this to `Configure.swift`
```swift
let monitoringConfg = MonitoringConfig(dashboard: false, prometheus: true, dashboardRoute: "", prometheusRoute: "customRoute", webSocketPort: 8888)
let router = try VaporMonitoring.setupMonitoring(&config, &services, monitoringConfg)
services.register(router, as: Router.self)
```
In this case, you'd have your prometheus metrics at `host:port/customRoute` and no dashboard would be provided.
