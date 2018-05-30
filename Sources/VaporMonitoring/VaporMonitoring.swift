//
//  VaporMonitoring.swift
//  VaporMonitoring
//
//  Created by Jari Koopman on 29/05/2018.
//

import Foundation
import SwiftMetrics
import Vapor

public struct LogData: SMData {
    public let timestamp: Int
    public let url: String
    public let requestDuration: Double
    public let statusCode: HTTPStatus
    public let method: HTTPMethod
}

public final class MonitoredResponder: Responder, ServiceType {
    public static var serviceSupports: [Any.Type] { return [Responder.self] }
    
    public static func makeService(for worker: Container) throws -> MonitoredResponder {
        let baseResponder = try worker.make(Responder.self)
        print(type(of: baseResponder))
        return MonitoredResponder.monitoring(responder: baseResponder)
    }
    
    public func respond(to req: Request) throws -> EventLoopFuture<Response> {
        // Logging
        print("RESPONDING TO \(req)")
        return try self.responder.respond(to: req)
    }
    
    private let responder: Responder
    
    init(responder: Responder) {
        self.responder = responder
    }
    
    public static func monitoring(responder: Responder) -> MonitoredResponder {
        return MonitoredResponder(responder: responder)
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
        print("ROUTING \(request)")
        return router.route(request: request)
    }

    /// the internal router
    private let router: Router

    /// The Swift Metrics instance
    let metrics: SwiftMetrics

    public init(swiftMetrics: SwiftMetrics, router: Router = EngineRouter.default()) throws {
        guard type(of: router) != type(of: self) else {
            throw VaporError(identifier: "routerType", reason: "Can't provide a `MonitoredRouter` to `MonitoredRouter`", suggestedFixes: ["Provide a different type of `Router` to `MonitoredRouter`"])
        }
        self.metrics = swiftMetrics
        self.router = router
    }
}

extension SwiftMetrics: Service { }
