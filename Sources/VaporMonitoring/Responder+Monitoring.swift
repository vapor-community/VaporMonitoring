//
//  Responder+Monitoring.swift
//  VaporMonitoring
//
//  Created by Jari Koopman on 01/06/2018.
//

import Foundation
import SwiftMetrics
import Vapor

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
