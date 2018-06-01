//
//  Router+Monitoring.swift
//  Async
//
//  Created by Jari Koopman on 01/06/2018.
//

import Foundation
import SwiftMetrics
import Vapor

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
