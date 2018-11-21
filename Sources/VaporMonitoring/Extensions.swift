//
//  Extensions.swift
//  VaporMonitoring
//
//  Created by Jari Koopman on 01/06/2018.
//

import Foundation
import SwiftMetrics
import Vapor

// MARK: - Vapor extensions

extension Request: Equatable {
    public static func == (lhs: Request, rhs: Request) -> Bool {
        return lhs.description == rhs.description && lhs.debugDescription == rhs.debugDescription
    }
}

/// Conforms SwiftMetrics to Service so we can register it with Vapor
extension SwiftMetrics: Service { }

public typealias requestClosure = (RequestData) -> ()

// MARK: - SwiftMetrics extensions

public extension SwiftMonitor.EventEmitter {
    static var requestObservers: [requestClosure] = []
    
    static func publish(data: RequestData) {
        for process in requestObservers {
            process(data)
        }
    }
    
    static func subscribe(callback: @escaping requestClosure) {
        requestObservers.append(callback)
    }
}

public extension SwiftMonitor {
    public func on(_ callback: @escaping requestClosure) {
        EventEmitter.subscribe(callback: callback)
    }
    
    func raiseEvent(data: RequestData) {
        EventEmitter.publish(data: data)
    }
}

public extension SwiftMetrics {
    public func emitData(_ data: RequestData) {
        if let monitor = swiftMon {
            monitor.raiseEvent(data: data)
        }
    }
}
