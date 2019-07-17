# VaporMonitoring
[![Vapor 3](https://img.shields.io/badge/vapor-3.0-blue.svg?style=flat)](https://vapor.codes)
[![Swift 4.2](https://img.shields.io/badge/swift-4.2-orange.svg?style=flat)](http://swift.org)

## Introduction

`VaporMonitoring` is a Vapor 3 package for monitoring and providing metrics for your Vapor application. Built on top of [the `swift-metrics` package](https://github.com/apple/swift-metrics) it also provides a helper to bootstrap [SwiftPrometheus](https://github.com/MrLotU/SwiftPrometheus). `VaporMonitoring` provides middleware which will [track metrics using the `RED` method for your application](https://www.weave.works/blog/the-red-method-key-metrics-for-microservices-architecture/):

1. Request Count
2. Error Count
3. Duration of each request

It breaks these out by URL path, status code, and method for fine-grained insight.

## Installation

Vapor Monitoring can be installed using SPM

```swift
.package(url: "https://github.com/vapor-community/VaporMonitoring.git", from: "3.0.0")
```

## Usage

### `MetricsMiddleware`

Most folks will want easy integration with `swift-metrics`, in which case you should use `MetricsMiddleware`.

Once you've brought the package into your project, you'll need to `import VaporMonitoring` in your `Configure.swift` file. Inside, you'll create a `MetricsMiddleware`:

```swift
services.register(MetricsMiddleware(), as: MetricsMiddleware.self)

var middlewares = MiddlewareConfig()
middlewares.use(MetricsMiddleware.self)
// Add other middleware, such as the Vapor-provided
middlewares.use(ErrorMiddleware.self)
services.register(middlewares)
```

This will place the monitoring inside your application, tracking incoming requests + outgoing responses, and calculating how long it takes for each to complete.

*Note*: Place the `MetricsMiddleware` in your `MiddlewareConfig` as early as possible (preferably first) so you can track the entire duration.

### Prometheus Integration

If you'd like to take advantage of a Prometheus installation, you'll need to export the `/metrics` endpoint in your list of routes:

```swift
let router = EngineRouter.default()
try routes(router)
let prometheusService = VaporPrometheus(router: router, route: "metrics")
services.register(prometheusService)
services.register(router, as: Router.self)
```

This will bootstrap `SwiftPrometheus` as your chosen backend, and also export metrics on `/metrics` (by default).
