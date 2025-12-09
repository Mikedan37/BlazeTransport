/// BlazeTransport - A QUIC-lite Swift-native transport protocol
/// with multi-streaming, reliability, congestion control, and typed messaging.
///
/// This package provides a high-level API for establishing connections,
/// opening streams, and sending/receiving Codable messages over a reliable,
/// congestion-controlled transport layer.
import Foundation

// MARK: - Public Error Types

/// Errors that can occur during transport operations.
public enum BlazeTransportError: Error {
    /// The connection has been closed.
    case connectionClosed
    /// The handshake process failed.
    case handshakeFailed
    /// Failed to encode a Codable value.
    case encodingFailed
    /// Failed to decode a Codable value.
    case decodingFailed
    /// A timeout occurred.
    case timeout
    /// An underlying error occurred (wraps the original error).
    case underlying(Error)
}

// MARK: - Public Configuration Types

/// Security configuration for transport connections.
public enum BlazeSecurityConfig {
    /// No encryption (for testing only).
    case none
    /// Default Blaze security: X25519 key exchange + AEAD encryption via BlazeBinary.
    case blazeDefault
}

// MARK: - Public Statistics

/// Transport-level statistics for monitoring connection health.
public struct BlazeTransportStats {
    /// Estimated round-trip time in seconds.
    public var roundTripTime: TimeInterval
    /// Current congestion window size in bytes.
    public var congestionWindowBytes: Int
    /// Packet loss rate (0.0 to 1.0).
    public var lossRate: Double
    /// Total bytes sent on this connection.
    public var bytesSent: Int
    /// Total bytes received on this connection.
    public var bytesReceived: Int

    /// Create transport statistics.
    public init(
        roundTripTime: TimeInterval,
        congestionWindowBytes: Int,
        lossRate: Double,
        bytesSent: Int,
        bytesReceived: Int
    ) {
        self.roundTripTime = roundTripTime
        self.congestionWindowBytes = congestionWindowBytes
        self.lossRate = lossRate
        self.bytesSent = bytesSent
        self.bytesReceived = bytesReceived
    }
}

// MARK: - Public Protocols

/// A connection to a remote host.
/// Supports opening multiple streams for concurrent data transfer.
public protocol BlazeConnection {
    /// Open a new stream on this connection.
    /// - Returns: A new stream for sending/receiving data.
    /// - Throws: `BlazeTransportError` if the connection is closed.
    func openStream() async throws -> BlazeStream
    
    /// Close this connection and all its streams.
    /// - Throws: `BlazeTransportError` if closing fails.
    func close() async throws
    
    /// Get current connection statistics.
    /// - Returns: Statistics including RTT, congestion window, and byte counts.
    func stats() async -> BlazeTransportStats
}

/// A bidirectional stream for sending and receiving typed messages.
/// Messages must conform to `Codable`.
public protocol BlazeStream {
    /// Send a Codable value over this stream.
    /// - Parameter value: The value to send (must conform to `Codable`).
    /// - Throws: `BlazeTransportError` if sending fails or stream is closed.
    func send<T: Codable>(_ value: T) async throws
    
    /// Receive a Codable value from this stream.
    /// - Parameter type: The type to decode (must conform to `Codable`).
    /// - Returns: The decoded value.
    /// - Throws: `BlazeTransportError` if receiving fails or stream is closed.
    func receive<T: Codable>(_ type: T.Type) async throws -> T
    
    /// Close this stream.
    /// - Throws: `BlazeTransportError` if closing fails.
    func close() async throws
}

// MARK: - Public API

/// Main entry point for BlazeTransport.
public enum BlazeTransport {
    /// Connect to a remote host.
    /// - Parameters:
    ///   - host: The hostname or IP address.
    ///   - port: The port number.
    ///   - security: Security configuration (defaults to `.blazeDefault`).
    /// - Returns: A connected `BlazeConnection`.
    /// - Throws: `BlazeTransportError` if connection fails.
    public static func connect(
        host: String,
        port: UInt16,
        security: BlazeSecurityConfig = .blazeDefault
    ) async throws -> BlazeConnection {
        let connection = DefaultBlazeConnection(host: host, port: port, security: security)
        try await connection.start()
        return connection
    }
}
