//
//  VaporMonitoring.swift
//  VaporMonitoring
//
//  Created by Jari Koopman on 29/05/2018.
//

import SwiftMetrics
import Vapor

/// Provides configuration for VaporMonitoring
public struct MonitoringConfig {
    /// At what route to host the Prometheus data
    var prometheusRoute: [String]
    
    /// Only display response times for builtin routes
    var onlyBuiltinRoutes: Bool
    
    public init(prometheusRoute: String..., onlyBuiltinRoutes: Bool) {
        self.prometheusRoute = prometheusRoute
        self.onlyBuiltinRoutes = onlyBuiltinRoutes
    }
    
    public static func `default`() -> MonitoringConfig {
        return .init(prometheusRoute: "metrics", onlyBuiltinRoutes: true)
    }
}

/// Vapor Monitoring class
/// Used to set up monitoring/metrics on your Vapor app
public final class VaporMonitoring {    
    /// Sets up config & services to monitor your Vapor app
    public static func setupMonitoring(_ config: inout Config, _ services: inout Services, _ monitorConfig: MonitoringConfig = .default()) throws -> MonitoredRouter {
        services.register(MonitoredResponder.self)
        config.prefer(MonitoredResponder.self, for: Responder.self)
        
        let metrics = try SwiftMetrics()
        services.register(metrics)
        
        let router = try MonitoredRouter(onlyBuiltinRoutes: monitorConfig.onlyBuiltinRoutes)
        config.prefer(MonitoredRouter.self, for: Router.self)
        
        let prometheus = try VaporMetricsPrometheus(metrics: metrics, router: router, route: monitorConfig.prometheusRoute)
        services.register(prometheus)
        
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
    var route: String
}

/// Log of requests
internal var requestsLog = [RequestLog]()

/// Timestamp for refference
internal var timeIntervalSince1970MilliSeconds: Double {
    return Date().timeIntervalSince1970 * 1000
}

internal var queue = DispatchQueue(label: "requestLogQueue")
