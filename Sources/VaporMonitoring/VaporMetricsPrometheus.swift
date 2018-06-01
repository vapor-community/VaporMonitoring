//
//  VaporMetricsPrometheus.swift
//  Async
//
//  Created by Jari Koopman on 31/05/2018.
//

import Foundation
import Vapor
import Configuration
import SwiftMetrics

public class HTTPDurationSummaryHandler {
    let handler: String
    var durations: [Double] = []
    var totalDuration: Double
    
    public init(handler: String, durationMicros: Double) {
        self.handler = handler
        self.totalDuration = 0
        addEvent(durationMicros: durationMicros)
    }
    
    func addEvent(durationMicros: Double) {
        durations.append(durationMicros)
        totalDuration += durationMicros
    }
    
    // Returns a dictionary mapping requested quantiles to values.
    public func calculateQuantiles(quantiles: [Double]) -> [Double: Double] {
        // Sort the list first!
        durations.sort()
        
        // Calculate each quantile.
        var quantileMap: [Double: Double] = [:]
        quantiles.forEach( {(q: Double) -> () in
            quantileMap[q] = quantile(q)
        })
        return quantileMap
    }
    
    
    // Given a value q calculate the q-Quantile value
    // from our set of durations.
    private func quantile( _ q : Double) -> Double {
        // Saves a lot of checks later on.
        // (We cannot have durations.count = 0 as we create this object
        // withthe first value.)
        if (durations.count == 1) {
            return durations[0];
        }
        
        let n : Double = Double(durations.count);
        if let pos = Int(exactly: (n*q)) {
            // pos is a whole number
            if (pos < 2) {
                // pos is 0 or 1.
                return durations[0]
            } else if (pos == durations.count) {
                // pos is last element, can't interpolate.
                return durations[pos - 1]
            }
            // take average of this and the next value.
            return (durations[pos - 1] + durations[pos]) / 2.0;
        } else {
            // If we don't divide perfectly take the nearest
            // value above.
            let pos : Int = Int((n * q).rounded(.up))
            return durations[pos - 1]
        }
    }
}

public class HTTPDurationSummary {
    
    var handlers: [String: HTTPDurationSummaryHandler] = [:]
    
    public init() { }
    
    public func addRequest(url: String, durationMicros: Double) {
        if let urlparser = URL(string: url) {
            let path = urlparser.path
            if let handler = handlers[path] {
                handler.addEvent(durationMicros: durationMicros)
            } else {
                handlers[path] = HTTPDurationSummaryHandler(handler: path, durationMicros: durationMicros)
            }
        }
    }
    
    public func writeCounts(writer:(HTTPDurationSummaryHandler)->()) {
        handlers.forEach { key, value in
            writer(value)
        }
    }
}

public class HTTPCounterHandler {
    let handler: String
    let statusCode: UInt
    let requestMethod: String
    var count: Int = 0
    
    public init(handler: String, statusCode: UInt, requestMethod: String) {
        self.handler = handler
        self.statusCode = statusCode
        self.requestMethod = requestMethod.lowercased()
    }
    
    func addEvent() {
        count += 1
    }
}

public class HTTPCounter {
    
    var handlers: [String: HTTPCounterHandler] = [:]
    
    public init() { }
    
    public func addRequest(url: String, statusCode: UInt, requestMethod: String) {
        
        if let urlparser = URL(string: url) {
            let path = urlparser.path
            let key: String = "\(path) \(statusCode) \(requestMethod)"
            if let handler = handlers[key] {
                handler.addEvent()
            } else {
                handlers[key] = HTTPCounterHandler(handler: path, statusCode: statusCode, requestMethod: requestMethod)
            }
        }
    }
    
    public func writeCounts(writer:(HTTPCounterHandler)->()) {
        handlers.forEach { key, value in
            writer(value)
        }
    }
}

var lastCPU: CPUData!
var lastMem: MemData!

var httpCounter: HTTPCounter = HTTPCounter()
var httpDurations: HTTPDurationSummary = HTTPDurationSummary()

func cpuEvent(cpu: CPUData) {
    lastCPU = cpu
}

func memEvent(mem: MemData) {
    lastMem = mem
}

func httpEvent(http: RequestData) {
    httpCounter.addRequest(url: http.url, statusCode: http.statusCode, requestMethod: http.method.string);
    httpDurations.addRequest(url: http.url, durationMicros: http.requestDuration * 1000.0);
    
}

/// Class providing Prometheus data
/// Powered by SwiftMetrics
public class VaporMetricsPrometheus: Vapor.Service {
    var monitor: SwiftMonitor
    var metrics: SwiftMetrics
    
    let p_quantiles: [Double] = [0.5,0.9,0.99]
    
    public init(metrics: SwiftMetrics, router: Router, route: String) throws {
        self.metrics = metrics
        self.monitor = metrics.monitor()
        
        monitor.on(cpuEvent)
        monitor.on(memEvent)
        monitor.on(httpEvent)
        
        router.get(route == "" ? "prometheus-metrics" : route, use: self.getPrometheusData)
    }
    
    func getPrometheusData(_ req: Request) throws -> String {
        var output = [String]()
        if (lastCPU != nil) {
            output.append("# HELP os_cpu_used_ratio The ratio of the systems CPU that is currently used (values are 0-1)\n")
            output.append("# TYPE os_cpu_used_ratio gauge\n")
            output.append("os_cpu_used_ratio \(lastCPU.percentUsedBySystem)\n")
            output.append("# HELP process_cpu_used_ratio The ratio of the process CPU that is currently used (values are 0-1)\n")
            output.append("# TYPE process_cpu_used_ratio gauge\n")
            output.append("process_cpu_used_ratio \(lastCPU.percentUsedByApplication)\n")
        }
        if (lastMem != nil) {
            output.append("# HELP os_resident_memory_bytes OS memory size in bytes.\n")
            output.append("# TYPE os_resident_memory_bytes gauge\n")
            output.append("os_resident_memory_bytes \(lastMem.totalRAMUsed)\n")
            output.append("# HELP process_resident_memory_bytes Resident memory size in bytes.\n")
            output.append("# TYPE process_resident_memory_bytes gauge\n")
            output.append("process_resident_memory_bytes \(lastMem.applicationRAMUsed)\n")
            output.append("# HELP process_virtual_memory_bytes Virtual memory size in bytes.\n")
            output.append("# TYPE process_virtual_memory_bytes gauge\n")
            output.append("process_virtual_memory_bytes \(lastMem.applicationAddressSpaceSize)\n")
        }
        // HTTP Counts
        output.append("# HELP http_requests_total Total number of HTTP requests made.\n")
        output.append("# TYPE http_requests_total counter\n")

        httpCounter.writeCounts { handler in
            output.append("http_requests_total{code=\"\(handler.statusCode)\", handler=\"\(handler.handler)\", method=\"\(handler.requestMethod)\"} \(handler.count)\n")
        }
        output.append("# HELP http_request_duration_microseconds The HTTP request latencies in microseconds.\n")
        output.append("# TYPE http_request_duration_microseconds summary\n")
        
        httpDurations.writeCounts { handler in
            output.append("http_request_duration_microseconds_sum{handler=\"\(handler.handler)\"} \(handler.totalDuration)\n")
            output.append("http_request_duration_microseconds_count{handler=\"\(handler.handler)\"} \(handler.durations.count)\n")
            let quantiles = handler.calculateQuantiles(quantiles:self.p_quantiles)
            quantiles.forEach { p, v in
                output.append("http_request_duration_microseconds{handler=\"\(handler.handler)\",quantile=\"\(p)\"} \(v)\n")
            }
        }

        
        return output.joined(separator: "")
    }
}
