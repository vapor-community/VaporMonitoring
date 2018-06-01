//
//  VaporMonitoring.swift
//  VaporMonitoring
//
//  Created by Jari Koopman on 29/05/2018.
//

import Foundation
import SwiftMetrics
import Vapor
import Leaf

/// Provides configuration for VaporMonitoring
public struct MonitoringConfig {
    var dashboard: Bool
    var prometheus: Bool
    var dashboardRoute: String
    var prometheusRoute: String
    
    public static func `default`() -> MonitoringConfig {
        return .init(dashboard: true, prometheus: true, dashboardRoute: "", prometheusRoute: "")
    }
}

/// Vapor Monitoring class
/// Used to set up monitoring/metrics on your Vapor app
public final class VaporMonitoring {
    /// Sets up config & services to monitor your Vapor app
    public static func setupMonitoring(_ config: inout Config, _ services: inout Services, _ monitorConfig: MonitoringConfig = .default()) throws -> MonitoredRouter {
        
        services.register(MonitoredResponder.self)
        config.prefer(MonitoredResponder.self, for: Responder.self)
        
        try services.register(LeafProvider())
        config.prefer(LeafRenderer.self, for: ViewRenderer.self)
        
        let metrics = try SwiftMetrics()
        services.register(metrics)
        
        let router = try MonitoredRouter()
        config.prefer(MonitoredRouter.self, for: Router.self)
        
        var middlewareConfig = MiddlewareConfig()
        middlewareConfig.use(FileMiddleware.self)
        services.register(middlewareConfig)
        
        if monitorConfig.dashboard {
            let dashboard = try VaporMetricsDash(metrics: metrics, router: router, route: monitorConfig.dashboardRoute)
            services.register(dashboard)
        }
        
        if monitorConfig.prometheus {
            let prometheus = try VaporMetricsPrometheus(metrics: metrics, router: router, route: monitorConfig.prometheusRoute)
            services.register(prometheus)
        }
        
        return router
    }
}

/// Data collected from each request
public struct RequestData: SMData {
    public let timestamp: Int
    public let url: String
    public let requestDuration: Double
    public let statusCode: UInt
    public let method: HTTPMethod
}

/// Log of request
internal struct RequestLog {
    var request: Request
    var timestamp: Double
}

/// Log of requests
internal var requestsLog = [RequestLog]()

/// Timestamp for refference
internal var timeIntervalSince1970MilliSeconds: Double {
    return Date().timeIntervalSince1970 * 1000
}

internal var queue = DispatchQueue(label: "requestLogQueue")
