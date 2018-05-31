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

public final class VaporMonitoring {
    public static func setupMonitoring(_ config: inout Config, _ env: inout Environment, _ services: inout Services) throws -> MonitoredRouter {
        
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
        
        services.register(VaporMetricsDash.self)
        
        let prometheus = try VaporMetricsPrometheus(metrics: metrics, router: router)
        services.register(prometheus)
        
        
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

private struct RequestLog {
    var request: Request
    var timestamp: Double
}

private var requestsLog = [RequestLog]()

private var timeIntervalSince1970MilliSeconds: Double {
    return Date().timeIntervalSince1970 * 1000
}

private var queue = DispatchQueue(label: "requestLogQueue")

extension Request: Equatable {
    public static func == (lhs: Request, rhs: Request) -> Bool {
        return lhs.description == rhs.description && lhs.debugDescription == rhs.debugDescription
    }
}

public final class MonitoredResponder: Responder, ServiceType {
    public static var serviceSupports: [Any.Type] { return [Responder.self] }
    
    public static func makeService(for worker: Container) throws -> MonitoredResponder {
        let baseResponder = try worker.make(ApplicationResponder.self)
        let metrics = try worker.make(SwiftMetrics.self)
        return MonitoredResponder.monitoring(responder: baseResponder, metrics: metrics)
    }
    
    public func respond(to req: Request) throws -> EventLoopFuture<Response> {
        // Logging
        return try self.responder.respond(to: req).map(to: Response.self, { (res) in
            queue.sync {
                for (index, r) in requestsLog.enumerated() {
                    if req == r.request {
                        self.metrics.emitData(RequestData(timestamp: Int(r.timestamp), url: r.request.http.urlString, requestDuration: timeIntervalSince1970MilliSeconds - r.timestamp, statusCode: res.http.status.code, method: r.request.http.method))
                        requestsLog.remove(at: index)
                        break
                    }
                }
            }
            return res
        })
    }
    
    private let responder: Responder
    private let metrics: SwiftMetrics
    
    init(responder: Responder, metrics: SwiftMetrics) {
        self.responder = responder
        self.metrics = metrics
    }
    
    public static func monitoring(responder: Responder, metrics: SwiftMetrics) -> MonitoredResponder {
        return MonitoredResponder(responder: responder, metrics: metrics)
    }
}

public final class MonitoredRouter: Router {
    public func register(route: Route<Responder>) {
        router.register(route: route)
    }

    public var routes: [Route<Responder>] {
        return router.routes
    }

    public func route(request: Request) -> Responder? {
        // Logging
        queue.sync {
            if requestsLog.count > 1000 {
                requestsLog.removeFirst()
            }
            requestsLog.append(RequestLog(request: request, timestamp: timeIntervalSince1970MilliSeconds))
        }
        
        return router.route(request: request)
    }

    /// the internal router
    private let router: Router

    public init(router: Router = EngineRouter.default()) throws {
        guard type(of: router) != type(of: self) else {
            throw VaporError(identifier: "routerType", reason: "Can't provide a `MonitoredRouter` to `MonitoredRouter`", suggestedFixes: ["Provide a different type of `Router` to `MonitoredRouter`"])
        }
        self.router = router
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
