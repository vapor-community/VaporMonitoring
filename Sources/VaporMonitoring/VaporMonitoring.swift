//
//  VaporMonitoring.swift
//  VaporMonitoring
//
//  Created by Jari Koopman on 29/05/2018.
//

import Foundation
import SwiftMetrics
import Vapor
import Leaf

/// Provides configuration for VaporMonitoring
public struct MonitoringConfig {
    /// Wether or not to create the VaporMetricsDashboard
    var dashboard: Bool
    /// Wether or not to serve Prometheus data
    var prometheus: Bool
    /// At what route to host the dashboard
    var dashboardRoute: String
    /// At what route to host the Prometheus data
    var prometheusRoute: String
    /// Port to create the WebSocket Server on.
    /// Used by the dashboard, defaults to 8888
    var webSocketPort: Int
    
    public init(dashboard: Bool, prometheus: Bool, dashboardRoute: String, prometheusRoute: String, webSocketPort: Int) {
        self.dashboard = dashboard
        self.prometheus = prometheus
        self.dashboardRoute = dashboardRoute
        self.prometheusRoute = prometheusRoute
        self.webSocketPort = webSocketPort
    }
    
    public static func `default`() -> MonitoringConfig {
        return .init(dashboard: true, prometheus: true, dashboardRoute: "", prometheusRoute: "", webSocketPort: 8888)
    }
}

/// Vapor Monitoring class
/// Used to set up monitoring/metrics on your Vapor app
public final class VaporMonitoring {
    /// Sets up config & services to monitor your Vapor app
    public static func setupMonitoring(_ config: inout Config, _ services: inout Services, _ monitorConfig: MonitoringConfig = .default()) throws -> MonitoredRouter {
        
        services.register(MonitoredResponder.self)
        config.prefer(MonitoredResponder.self, for: Responder.self)
        
        let metrics = try SwiftMetrics()
        services.register(metrics)
        
        let router = try MonitoredRouter()
        config.prefer(MonitoredRouter.self, for: Router.self)
        
        if monitorConfig.dashboard && publicDir != "" {
            let publicDir = getPublicDir()
            let fileMiddelware = FileMiddleware(publicDirectory: publicDir)
            
            var middlewareConfig = MiddlewareConfig()
            middlewareConfig.use(fileMiddelware)
            services.register(middlewareConfig)
            services.register { (container) -> (VaporMetricsDash) in
                let dashboard = try VaporMetricsDash(metrics: metrics, router: router, route: monitorConfig.dashboardRoute, port: monitorConfig.webSocketPort, worker: container)
                return dashboard
            }
        }
        
        if monitorConfig.prometheus {
            let prometheus = try VaporMetricsPrometheus(metrics: metrics, router: router, route: monitorConfig.prometheusRoute)
            services.register(prometheus)
        }
        
        return router
    }
    
    static var publicDir: String {
        return getPublicDir()
    }
    
    static func getPublicDir() -> String {
        var appPath = ""
        var workingPath = ""
        let fm = FileManager.default
        let currentDir = fm.currentDirectoryPath
        if currentDir.contains(".build") {
            workingPath = currentDir
        }
        if let i = workingPath.range(of: ".build") {
            appPath = String(workingPath[..<i.lowerBound])
        }
        let checkoutsPath = appPath + ".build/checkouts/"
        if fm.fileExists(atPath: checkoutsPath) {
            _ = fm.changeCurrentDirectoryPath(checkoutsPath)
        }
        do {
            let dirContents = try fm.contentsOfDirectory(atPath: fm.currentDirectoryPath)
            for dir in dirContents {
                if dir.contains("VaporMonitoring") {
                    ///that's where we want to be!
                    _ = fm.changeCurrentDirectoryPath(dir)
                }
            }
        } catch {
            print("SwiftMetrics: Error obtaining contents of directory: \(fm.currentDirectoryPath), \(error).")
            return ""
        }
        let fileName = NSString(string: #file)
        let installDirPrefixRange: NSRange
        let installDir = fileName.range(of: "/Sources/VaporMonitoring/VaporMonitoring.swift", options: .backwards)
        if  installDir.location != NSNotFound {
            installDirPrefixRange = NSRange(location: 0, length: installDir.location)
        } else {
            installDirPrefixRange = NSRange(location: 0, length: fileName.length)
        }
        let folderName = fileName.substring(with: installDirPrefixRange)
        return folderName + "/Public"
    }
}

/// Data collected from each request
public struct RequestData: SMData {
    public let timestamp: Int
    public let url: String
    public let requestDuration: Double
    public let statusCode: UInt
    public let method: HTTPMethod
}

/// Log of request
internal struct RequestLog {
    var request: Request
    var timestamp: Double
}

/// Log of requests
internal var requestsLog = [RequestLog]()

/// Timestamp for refference
internal var timeIntervalSince1970MilliSeconds: Double {
    return Date().timeIntervalSince1970 * 1000
}

internal var queue = DispatchQueue(label: "requestLogQueue")
