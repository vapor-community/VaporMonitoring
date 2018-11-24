//
//  VaporMetricsPrometheus.swift
//  VaporMonitoring
//
//  Created by Jari Koopman on 31/05/2018.
//

import Vapor
import SwiftMetrics
import Prometheus

let osCPUUsed = Prometheus.shared.createGauge(forType: Float.self, named: "os_cpu_used_ratio", helpText: "The ratio of the systems CPU that is currently used (values are 0-1)")
let processCPUUsed = Prometheus.shared.createGauge(forType: Float.self, named: "process_cpu_used_ratio", helpText: "The ratio of the process CPU that is currently used (values are 0-1)")

let osResidentBytes = Prometheus.shared.createGauge(forType: Int.self, named: "os_resident_memory_bytes", helpText: "OS memory size in bytes.")
let processResidentBytes = Prometheus.shared.createGauge(forType: Int.self, named: "process_resident_memory_bytes", helpText: "Resident memory size in bytes.")
let processVirtualBytes = Prometheus.shared.createGauge(forType: Int.self, named: "process_virtual_memory_bytes", helpText: "Virtual memory size in bytes.")

let requestsTotal = Prometheus.shared.createCounter(forType: Int.self, named: "http_requests_total", helpText: "Total number of HTTP requests made.", withLabelType: TotalRequestsLabels.self)

let requestDuration = Prometheus.shared.createSummary(forType: Double.self, named: "http_request_duration_microseconds", helpText: "The HTTP request latencies in microseconds.", labels: RequestDurationLabels.self)


func cpuEvent(cpu: CPUData) {
    osCPUUsed.set(cpu.percentUsedBySystem)
    processCPUUsed.set(cpu.percentUsedByApplication)
}

func memEvent(mem: MemData) {
    osResidentBytes.set(mem.totalRAMUsed)
    processResidentBytes.set(mem.applicationRAMUsed)
    processVirtualBytes.set(mem.applicationAddressSpaceSize)
}

func httpEvent(http: RequestData) {
    requestsTotal.inc(1, TotalRequestsLabels(http.statusCode, http.url, http.method.string))
    requestDuration.observe(http.requestDuration * 1000.0, RequestDurationLabels(http.url))
}

struct TotalRequestsLabels: MetricLabels {
    let code: UInt
    let handler: String
    let method: String
    
    init() {
        self.code = 0
        self.handler = "*"
        self.method = "*"
    }
    
    init(_ c: UInt, _ h: String, _ m: String) {
        self.code = c
        self.handler = h
        self.method = m
    }
}

struct RequestDurationLabels: SummaryLabels {
    var quantile: String = ""
    let handler: String
    
    init() {
        self.handler = "*"
    }
    
    init(_ h: String) {
        self.handler = h
    }
}

/// Class providing Prometheus data
/// Powered by SwiftMetrics
public class VaporMetricsPrometheus: Service {
    var monitor: SwiftMonitor
    var metrics: SwiftMetrics
    
    let p_quantiles: [Double] = [0.5,0.9,0.99]
    
    public init(metrics: SwiftMetrics, router: Router, route: [String]) throws {
        self.metrics = metrics
        self.monitor = metrics.monitor()
        
        monitor.on(cpuEvent)
        monitor.on(memEvent)
        monitor.on(httpEvent)

        // TBH, I feel like this should be possible in a nicer way
        // But route.convertToPathComponents() gives all kinds of errors :L
        router.get(route.map { $0 }, use: self.getPrometheusData)
    }
    
    func getPrometheusData(_ req: Request) throws -> String {
        return Prometheus.shared.getMetrics()
    }
}

