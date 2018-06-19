import Vapor
import VaporMonitoring
import SwiftMetrics
import Leaf

public func routes(_ router: Router) throws {
    // Basic "Hello, world!" example
    router.get("hello") { req in
        return "Hello, world!"
    }
}

/// Called before your application initializes.
public func configure(_ config: inout Config, _ env: inout Environment, _ services: inout Services) throws {
    /// Register routes to the router
    
    let router = try VaporMonitoring.setupMonitoring(&config, &services)
    
    try routes(router)
    services.register(router, as: Router.self)
}

/// Called after your application has initialized.
public func boot(_ app: Application) throws {
}

/// Creates an instance of Application. This is called from main.swift in the run target.
public func app(_ env: Environment) throws -> Application {
    var config = Config.default()
    var env = env
    var services = Services.default()
    try configure(&config, &env, &services)
    let app = try Application(config: config, environment: env, services: services)
    try boot(app)
    return app
}

/// Register your application's routes here.

try app(.detect()).run()
