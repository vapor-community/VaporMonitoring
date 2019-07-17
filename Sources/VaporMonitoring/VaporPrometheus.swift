//
//  VaporPrometheus.swift
//  VaporMonitoring
//
//  Created by Joe Smith on 07/16/2019.
//

import Vapor
import Metrics
import Prometheus

/// Class providing Prometheus data
public class VaporPrometheus: Service {
    let prometheusClient = PrometheusClient()

    let p_quantiles: [Double] = [0.5,0.9,0.99]
    
    public init(router: Router, route: String) {
        Metrics.MetricsSystem.bootstrap(prometheusClient)
        router.get(route, use: self.getPrometheusData)
    }

    func getPrometheusData(_ req: Request) throws -> Future<String> {
        // The underlying API here should update to return a Future we can just return directly.
        let promise = req.eventLoop.newPromise(String.self)
        promise.succeed(result: prometheusClient.collect())
        return promise.futureResult
    }
}
