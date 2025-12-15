/// Default implementation of BlazeConnection protocol.
/// Wraps ConnectionManager and provides public API.
import Foundation

/// Internal implementation of BlazeConnection.
actor DefaultBlazeConnection: BlazeConnection {
    private let host: String
    private let port: UInt16
    private let security: BlazeSecurityConfig
    let connectionManager: ConnectionManager
    private var isStarted = false

    init(host: String, port: UInt16, security: BlazeSecurityConfig, useMockSocket: Bool = false) {
        self.host = host
        self.port = port
        self.security = security
        self.connectionManager = ConnectionManager(host: host, port: port, security: security, useMockSocket: useMockSocket)
    }

    func start() async throws {
        guard !isStarted else { return }
        isStarted = true
        try await connectionManager.start()
    }

    func openStream() async throws -> BlazeStream {
        return try await connectionManager.openStream()
    }

    func close() async throws {
        try await connectionManager.close()
    }

    func stats() async -> BlazeTransportStats {
        return await connectionManager.stats()
    }
}

