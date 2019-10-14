import XCTest
@testable import VaporMonitoring

import HTTP
import Metrics
import Prometheus
import Vapor

final class VaporMonitoringTests: XCTestCase {
    public struct TestError: Error { }

    let elg = MultiThreadedEventLoopGroup(numberOfThreads: 1)

    public func routes(_ router: Router) throws {
        router.get("posts") { req in
            return "Hello, world!"
        }
    }

    func makeRequest(_ url: String, middleware: Middleware, container: Container) throws {
        let httpRequest = HTTPRequest(method: .GET, url: url, version: .init(major: 1, minor: 1), headers: HTTPHeaders(), body: HTTPBody())
        let request = Vapor.Request(http: httpRequest, using: container)
        let responder = BasicResponder { request in
            if !request.http.url.path.contains("9001") {
                return self.elg.next().newSucceededFuture(result: Response(using: container))
            } else {
                return self.elg.next().newFailedFuture(error: TestError())
            }
        }

        // Trigger the request
        let response = try middleware.respond(to: request, chainingTo: responder)
        do {
            _ = try response.wait()
        } catch is TestError { /* expected */ }
    }

    func testVaporMonitoring() throws {
        // Setup Middleware
        var services = Services.default()
        let middleware = MetricsMiddleware()
        services.register(MetricsMiddleware(), as: MetricsMiddleware.self)
        var middlewares = MiddlewareConfig()
        middlewares.use(MetricsMiddleware.self)
        services.register(middlewares)

        // Create VaporPrometheus
        let router = EngineRouter.default()
        try routes(router)
        let prometheusService = VaporPrometheus(router: router, services: &services)
        services.register(prometheusService)
        services.register(router, as: Router.self)

        // Prepare fake HTTP request
        let testContainer = BasicContainer(config: Config(), environment: Environment.testing, services: Services.default(), on: elg)

        for _ in 1...5 {
            try makeRequest("http://fake-blog.com", middleware: middleware, container: testContainer)
        }

        for postID in [1, 1, 1, 1, 2, 3, 4, 5, 9001, 9001] {
            try makeRequest("http://fake-blog.com/posts/\(postID)", middleware: middleware, container: testContainer)
        }

        // Verify we captured as expected
        let prom = try MetricsSystem.prometheus()
        let metricsPromise = elg.next().newPromise(of: String.self)
        prom.collect(into: metricsPromise)
        let metrics = try metricsPromise.futureResult.wait().split(separator: "\n").map { String($0) }

        let expectedResults = [
            #"http_requests_total{status_code="200", path="/", method="GET"} 5"#,
            #"http_requests_total{status_code="200", path="posts", method="GET"} 8"#,
            "http_requests_duration_seconds_count 15",
            #"http_requests_duration_seconds_count{path="posts", method="GET"} 10"#,
            #"http_request_errors_total{path="posts", method="GET"} 2"#
        ]
        for result in expectedResults {
            XCTAssert(metrics.contains(result))
        }
    }
}
