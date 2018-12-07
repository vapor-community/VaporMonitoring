//
//  Router+Monitoring.swift
//  VaporMonitoring
//
//  Created by Jari Koopman on 01/06/2018.
//

import Foundation
import SwiftMetrics
import Vapor

/// Router subclass adding monitoring
/// Built on top of a router of your choosing (defaults to the default EngineRouter)
public final class MonitoredRouter: Router {
    /// See `Router.register`
    public func register(route: Route<Responder>) {
        router.register(route: route)
    }
    
    /// See `Router.routes`
    public var routes: [Route<Responder>] {
        return router.routes
    }
    
    /// See `Router.route`
    /// Adds logging to routing a request
    public func route(request: Request) -> Responder? {
        
        let result = router.route(request: request)
        
        // Logging
        queue.sync {
            var path: String = request.http.urlString
            if onlyBuiltinRoutes {
                guard let _ = result, let route = routes.first(where: { (route) -> Bool in
                    route.path.readable == "/\(request.http.method.string)\(request.http.url.path)"
                }) else { return }
                path = route.path.readable
            }
            
            if requestsLog.count > 1000 {
                requestsLog.removeFirst()
            }
            requestsLog.append(RequestLog(request: request, timestamp: timeIntervalSince1970MilliSeconds, route: path))
        }
        
        return result
    }
    
    /// The internal router
    private let router: Router
    
    /// Show only builtin routes in metrics
    private let onlyBuiltinRoutes: Bool
    
    /// Initializes MonitoredRouter with internal with an internal router to use for actual routing
    public init(router: Router = EngineRouter.default(), onlyBuiltinRoutes: Bool = true) throws {
        guard type(of: router) != type(of: self) else {
            throw VaporError(identifier: "routerType", reason: "Can't provide a `MonitoredRouter` to `MonitoredRouter`", suggestedFixes: ["Provide a different type of `Router` to `MonitoredRouter`"])
        }
        self.router = router
        self.onlyBuiltinRoutes = onlyBuiltinRoutes
    }
}
