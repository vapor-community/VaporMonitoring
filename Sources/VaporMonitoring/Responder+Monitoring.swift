//
//  Responder+Monitoring.swift
//  VaporMonitoring
//
//  Created by Jari Koopman on 01/06/2018.
//

import Foundation
import SwiftMetrics
import Vapor

/// Responder subclass adding monitoring
/// Built on top of a responder of your choosing (defaults to the default ApplicationResponder)
public final class MonitoredResponder: Responder, ServiceType {
    /// See `ServiceType`
    public static var serviceSupports: [Any.Type] { return [Responder.self] }

    /// See `ServiceType`
    public static func makeService(for worker: Container) throws -> MonitoredResponder {
        let baseResponder = try worker.make(ApplicationResponder.self)
        let metrics = try worker.make(SwiftMetrics.self)
        return try MonitoredResponder.monitoring(responder: baseResponder, metrics: metrics)
    }
    
    /// See `Responder.respond`
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
    
    /// Internal responder
    private let responder: Responder
    /// SwiftMetrics instance
    private let metrics: SwiftMetrics
    
    /// Creates a new MonitoredResponder with provided Responder and Metrics
    init(responder: Responder, metrics: SwiftMetrics) throws {
        guard type(of: responder) != type(of: self) else {
            throw VaporError(identifier: "responderType", reason: "Can't provide a `MonitoredResponder` to `MonitoredResponder`", suggestedFixes: ["Provide a different type of `Responder` to `MonitoredResponder`"])
        }
        self.responder = responder
        self.metrics = metrics
    }
    
    /// Easy initalization of monitored resonder
    public static func monitoring(responder: Responder, metrics: SwiftMetrics) throws -> MonitoredResponder {
        return try MonitoredResponder(responder: responder, metrics: metrics)
    }
}
