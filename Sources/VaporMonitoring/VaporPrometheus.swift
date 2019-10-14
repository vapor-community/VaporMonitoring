import Vapor
import Metrics
import Prometheus

/// Class providing Prometheus data
///
/// This class will automatically register its Prometheus client with `swift-metrics` for you.
public class VaporPrometheus: Service {
    let prometheusClient = PrometheusClient()

    public init(router: Router, services: inout Services, route: String = "metrics") {
        services.register(prometheusClient, as: PrometheusClient.self)
        MetricsSystem.bootstrap(prometheusClient)
        router.get(route, use: self.getPrometheusData)
    }

    func getPrometheusData(_ req: Request) throws -> Future<String> {
        // The underlying API here should update to return a Future we can just return directly.
        let promise = req.eventLoop.newPromise(String.self)
        prometheusClient.collect(into: promise)
        return promise.futureResult
    }
}

extension PrometheusClient: Service { }
