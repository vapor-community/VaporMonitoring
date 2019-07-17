//
//  MetricsMiddleware.swift
//  VaporMonitoring
//
//  Created by Joe Smith on 07/15/2019.
//

import Metrics
import Vapor

/// Middleware to track in per-request metrics
///
/// Based [off the RED Method](https://www.weave.works/blog/the-red-method-key-metrics-for-microservices-architecture/)
public final class MetricsMiddleware {
    public let requestsCounterLabel = "http_requests_total"
    public let requestsTimerLabel = "http_requests_duration_seconds"
    // private let requestErrorsCounter = Metrics.Counter(label: "http_request_errors_total", dimensions: [(String, String)]()) NEED TO ADD ERRORS

    public init() { }
}

extension MetricsMiddleware: Middleware {
    public func respond(to request: Request, chainingTo next: Responder) throws -> EventLoopFuture<Response> {
        let start = Date()
        let response: Future<Response>
        do {
            response = try next.respond(to: request)
        } catch {
            response = request.eventLoop.newFailedFuture(error: error)
        }
        return response.map { response in
            let dimensions = [
                ("method", request.http.method.string),
                ("path", request.http.url.path),
                ("status_code", "\(response.http.status.code)")]
            Metrics.Counter(label: self.requestsCounterLabel, dimensions: dimensions).increment()
            let duration = start.timeIntervalSinceNow * -1
            Metrics.Timer(label: self.requestsTimerLabel, dimensions: dimensions).record(duration)
            return response
        } // should we also handle the failed future too?
    }
}

extension MetricsMiddleware: ServiceType {
    public static func makeService(for container: Container) throws -> MetricsMiddleware {
        return MetricsMiddleware()
    }
}
