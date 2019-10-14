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
    let requestsCounterLabel = "http_requests_total"
    let requestsTimerLabel = "http_requests_duration_seconds"
    let requestErrorsLabel = "http_request_errors_total"

    public init() { }
}

extension MetricsMiddleware: Middleware {
    public func respond(to request: Request, chainingTo next: Responder) throws -> EventLoopFuture<Response> {
        let start = Date().timeIntervalSince1970
        let response: Future<Response>
        do {
            response = try next.respond(to: request)
        } catch {
            response = request.eventLoop.newFailedFuture(error: error)
        }

        _ = response.map { response in
            self.updateMetrics(for: request, responseCounterName: self.requestsCounterLabel, start: start, statusCode: response.http.status.code)
        }.mapIfError { error in
            self.updateMetrics(for: request, responseCounterName: self.requestErrorsLabel, start: start)
        }

        return response
    }

    private func updateMetrics(for request: Request, responseCounterName: String, start: Double, statusCode: UInt? = nil) {
        let topLevel = String(request.http.url.path.split(separator: "/").first ?? "/")
        var counterDimensions = [
            ("method", request.http.method.string),
            ("path", topLevel)]
        if let statusCode = statusCode {
            counterDimensions.append(("status_code", "\(statusCode)"))
        }
        let timerDimensions = [
            ("method", request.http.method.string),
            ("path", topLevel)]
        let end = Date().timeIntervalSince1970
        let duration = end - start

        Metrics.Counter(label: responseCounterName, dimensions: counterDimensions).increment()
        Metrics.Timer(label: self.requestsTimerLabel, dimensions: timerDimensions, preferredDisplayUnit: .seconds).recordSeconds(duration)
    }
}

extension MetricsMiddleware: ServiceType {
    public static func makeService(for container: Container) throws -> MetricsMiddleware {
        return MetricsMiddleware()
    }
}
