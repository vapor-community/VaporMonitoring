//
//  VaporMetricsDashboard.swift
//  VaporMonitoring
//
//  Created by Jari Koopman on 30/05/2018.
//

import Foundation
import Vapor
import SwiftMetrics
import SwiftyJSON
import Foundation
import Configuration
import CloudFoundryEnv
import Dispatch
import Leaf

struct HTTPAggregateData: SMData {
    public var timeOfRequest: Int = 0
    public var url: String = ""
    public var longest: Double = 0
    public var average: Double = 0
    public var total: Int = 0
}

/// Vapor Metrics Dashboard
/// Provides a HTML dashboard showing metrics of current running application
public class VaporMetricsDash: Vapor.Service {
    var monitor: SwiftMonitor
    var metrics: SwiftMetrics
    var service: VaporMetricsService
    var route: String
    
    public init(metrics: SwiftMetrics, router: Router, route: String) throws {
        self.metrics = metrics
        self.monitor = metrics.monitor()
        self.service = VaporMetricsService(monitor: self.monitor)
        self.route = route == "" ? "metrics" : route
        router.get(self.route, use: render)
//        try self.startWS(worker: worker)
    }
    
    func socketHandler(_ ws: WebSocket, req: Request) throws {
        guard req.http.headers.firstValue(name: .secWebSocketProtocol) == "swiftmetrics-dash" else { return }
        self.service.connect(ws)
        ws.onClose.always {
            self.service.disconnect(ws)
        }
    }
    
    /// Render the HTML dashboard
    func render(_ req: Request) throws -> Future<View> {
        let config = LeafConfig(tags: .default(), viewsDir: VaporMonitoring.publicDir, shouldCache: false)
        let renderer = LeafRenderer(config: config, using: req)
        return renderer.render("index", TemplateData.bool(true))
    }
}

/// Service gathering all data required for the dashboard
/// And providing the data to the connected WebSockets
public class VaporMetricsService {
    private var conns = [UUID: WebSocket]()
    var httpAggregateData: HTTPAggregateData = HTTPAggregateData()
    var httpURLData:[String:(totalTime:Double, numHits:Double, longestTime:Double)] = [:]
    let httpURLsQueue = DispatchQueue(label: "httpURLsQueue")
    let httpQueue = DispatchQueue(label: "httpStoreQueue")
    let jobsQueue = DispatchQueue(label: "jobsQueue")
    var monitor:SwiftMonitor
    
    // CPU summary data
    var totalProcessCPULoad: Double = 0.0
    var totalSystemCPULoad: Double = 0.0
    var cpuLoadSamples: Double = 0
    
    // Memory summary data
    var totalProcessMemory: Int = 0
    var totalSystemMemory: Int = 0
    var memorySamples: Int = 0
    
    public init(monitor: SwiftMonitor) {
        self.monitor = monitor
        monitor.on(sendCPU)
        monitor.on(sendMEM)
        monitor.on(storeHTTP)
        sendhttpData()
    }
    
    func sendCPU(cpu: CPUData) {
        totalProcessCPULoad += Double(cpu.percentUsedByApplication);
        totalSystemCPULoad += Double(cpu.percentUsedBySystem);
        cpuLoadSamples += 1;
        let processMean = (totalProcessCPULoad / cpuLoadSamples);
        let systemMean = (totalSystemCPULoad / cpuLoadSamples);
        
        let cpuLine = JSON(["topic":"cpu", "payload":["time":"\(cpu.timeOfSample)","process":"\(cpu.percentUsedByApplication)","system":"\(cpu.percentUsedBySystem)","processMean":"\(processMean)","systemMean":"\(systemMean)"]])

        for (_, conn) in self.conns {
            if let data = cpuLine.rawString() {
                conn.send(data)
            }
        }
    }
    
    func sendMEM(mem: MemData) {
        totalProcessMemory += mem.applicationRAMUsed;
        totalSystemMemory += mem.totalRAMUsed;
        memorySamples += 1;
        let processMean = (totalProcessMemory / memorySamples);
        let systemMean = (totalSystemMemory / memorySamples);
        
        let memLine = JSON(["topic":"memory","payload":[
            "time":"\(mem.timeOfSample)",
            "physical":"\(mem.applicationRAMUsed)",
            "physical_used":"\(mem.totalRAMUsed)",
            "processMean":"\(processMean)",
            "systemMean":"\(systemMean)"
            ]])
        
        for (_, conn) in self.conns {
            if let data = memLine.rawString() {
                conn.send(data)
            }
        }
    }
    
    public func connect(_ conn: WebSocket) {
        conns[conn.id] = conn
        getenvRequest()
        sendTitle()
    }
    
    public func disconnect(_ conn: WebSocket) {
        conns.removeValue(forKey: conn.id)
    }
    
    public func getenvRequest()  {
        var commandLine = ""
        var hostname = ""
        var os = ""
        var numPar = ""
        
        for (param, value) in self.monitor.getEnvironmentData() {
            switch param {
            case "command.line":
                commandLine = value
                break
            case "environment.HOSTNAME":
                hostname = value
                break
            case "os.arch":
                os = value
                break
            case "number.of.processors":
                numPar = value
                break
            default:
                break
            }
        }
        
        
        let envLine = JSON(["topic":"env","payload":[
            ["Parameter":"Command Line","Value":"\(commandLine)"],
            ["Parameter":"Hostname","Value":"\(hostname)"],
            ["Parameter":"Number of Processors","Value":"\(numPar)"],
            ["Parameter":"OS Architecture","Value":"\(os)"]
            ]])
        
        for (_, conn) in self.conns {
            if let data = envLine.rawString() {
                conn.send(data)
            }
        }
    }
    
    public func sendTitle()  {
        let titleLine = JSON(["topic":"title","payload":[
            "title":"Application Metrics for Swift",
            "docs": "http://github.com/RuntimeTools/SwiftMetrics"]])
        
        for (_, conn) in self.conns {
            if let data = titleLine.rawString() {
                conn.send(data)
            }
        }
    }
    
    public func storeHTTP(myhttp: RequestData) {
        let localmyhttp = myhttp
        httpQueue.sync {
            if self.httpAggregateData.total == 0 {
                self.httpAggregateData.total = 1
                self.httpAggregateData.timeOfRequest = localmyhttp.timestamp
                self.httpAggregateData.url = localmyhttp.url
                self.httpAggregateData.longest = localmyhttp.requestDuration
                self.httpAggregateData.average = localmyhttp.requestDuration
            } else {
                let oldTotalAsDouble:Double = Double(self.httpAggregateData.total)
                let newTotal = self.httpAggregateData.total + 1
                self.httpAggregateData.total = newTotal
                self.httpAggregateData.average = (self.httpAggregateData.average * oldTotalAsDouble + localmyhttp.requestDuration) / Double(newTotal)
                if (localmyhttp.requestDuration > self.httpAggregateData.longest) {
                    self.httpAggregateData.longest = localmyhttp.requestDuration
                    self.httpAggregateData.url = localmyhttp.url
                }
            }
        }
        httpURLsQueue.async {
            let urlTuple = self.httpURLData[localmyhttp.url]
            if(urlTuple != nil) {
                let averageResponseTime = urlTuple!.0
                let hits = urlTuple!.1
                var longest = urlTuple!.2
                if (localmyhttp.requestDuration > longest) {
                    longest = localmyhttp.requestDuration
                }
                // Recalculate the average
                self.httpURLData.updateValue(((averageResponseTime * hits + localmyhttp.requestDuration)/(hits + 1), hits + 1, longest), forKey: localmyhttp.url)
            } else {
                self.httpURLData.updateValue((localmyhttp.requestDuration, 1, localmyhttp.requestDuration), forKey: localmyhttp.url)
            }
        }
    }
    
    func sendhttpData()  {
        httpQueue.sync {
            let localCopy = self.httpAggregateData
            if localCopy.total > 0 {
                let httpLine = JSON([
                    "topic":"http","payload":[
                        "time":"\(localCopy.timeOfRequest)",
                        "url":"\(localCopy.url)",
                        "longest":"\(localCopy.longest)",
                        "average":"\(localCopy.average)",
                        "total":"\(localCopy.total)"]])
                
                for (_, conn) in self.conns {
                    if let messageToSend = httpLine.rawString() {
                        conn.send(messageToSend)
                    }
                }
                self.httpAggregateData = HTTPAggregateData()
            }
        }
        httpURLsQueue.sync {
            var responseData:[JSON] = []
            let localCopy = self.httpURLData
            for (key, value) in localCopy {
                let json = JSON(["url":key, "averageResponseTime": value.0, "hits": value.1, "longestResponseTime": value.2])
                responseData.append(json)
            }
            var messageToSend:String=""
            
            // build up the messageToSend string
            for response in responseData {
                messageToSend += response.rawString()! + ","
            }
            
            if !messageToSend.isEmpty {
                // remove the last ','
                messageToSend = String(messageToSend[..<messageToSend.index(before: messageToSend.endIndex)])
                // construct the final JSON obkect
                let data = "{\"topic\":\"httpURLs\",\"payload\":[" + messageToSend + "]}"
                for (_,conn) in self.conns {
                    conn.send(data)
                }
            }
            jobsQueue.async {
                // re-run this function after 2 seconds
                sleep(2)
                self.sendhttpData()
            }
        }
    }
}







