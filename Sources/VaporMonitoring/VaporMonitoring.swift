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

public struct MonitoringConfig {
    var dashboard: Bool
    var prometheus: Bool
    var dashboardRoute: String
    var prometheusRoute: String
    
    public static func `default`() -> MonitoringConfig {
        return .init(dashboard: true, prometheus: true, dashboardRoute: "", prometheusRoute: "")
    }
}

public final class VaporMonitoring {
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

public struct RequestData: SMData {
    public let timestamp: Int
    public let url: String
    public let requestDuration: Double
    public let statusCode: UInt
    public let method: HTTPMethod
}

internal struct RequestLog {
    var request: Request
    var timestamp: Double
}

internal var requestsLog = [RequestLog]()

internal var timeIntervalSince1970MilliSeconds: Double {
    return Date().timeIntervalSince1970 * 1000
}

internal var queue = DispatchQueue(label: "requestLogQueue")

extension Request: Equatable {
    public static func == (lhs: Request, rhs: Request) -> Bool {
        return lhs.description == rhs.description && lhs.debugDescription == rhs.debugDescription
    }
}

extension SwiftMetrics: Service { }

public typealias requestClosure = (RequestData) -> ()

public extension SwiftMonitor.EventEmitter {
    static var requestObservers: [requestClosure] = []
    
    static func publish(data: RequestData) {
        for process in requestObservers {
            process(data)
        }
    }
    
    static func subscribe(callback: @escaping requestClosure) {
        requestObservers.append(callback)
    }
}

public extension SwiftMonitor {
    public func on(_ callback: @escaping requestClosure) {
        EventEmitter.subscribe(callback: callback)
    }
    
    func raiseEvent(data: RequestData) {
        EventEmitter.publish(data: data)
    }
}

public extension SwiftMetrics {
    public func emitData(_ data: RequestData) {
        if let monitor = swiftMon {
            monitor.raiseEvent(data: data)
        }
    }
}
