/// BlazeTransport - A QUIC-lite Swift-native transport protocol
/// with multi-streaming, reliability, congestion control, and typed messaging.
///
/// BlazeTransport provides a high-level, type-safe API for establishing connections,
/// opening streams, and sending/receiving Codable messages over a reliable,
/// congestion-controlled transport layer built on UDP.
///
/// ## Overview
///
/// BlazeTransport is designed for Swift applications that need:
/// - Low-latency, reliable message delivery
/// - Multiple concurrent streams per connection
/// - Type-safe messaging with Codable
/// - Built-in encryption and security
/// - QUIC-like performance without C interop overhead
///
/// ## Example
///
/// ```swift
/// let connection = try await BlazeTransport.connect(
///     host: "example.com",
///     port: 9999,
///     security: .blazeDefault
/// )
/// let stream = try await connection.openStream()
/// try await stream.send("Hello, Blaze!")
/// let reply: String = try await stream.receive(String.self)
/// ```
///
/// - Since: 0.1.0
import Foundation

// MARK: - Public Error Types

/// Errors that can occur during BlazeTransport operations.
///
/// All errors are recoverable except `connectionClosed`, which indicates
/// the connection has been terminated and cannot be reused.
///
/// - Since: 0.1.0
public enum BlazeTransportError: Error, Sendable {
    /// The connection has been closed and cannot be used.
    ///
    /// This error is thrown when attempting to use a connection or stream
    /// that has been closed. Create a new connection to continue.
    case connectionClosed
    
    /// The cryptographic handshake process failed.
    ///
    /// This typically indicates a network issue, authentication failure,
    /// or incompatible security configuration with the remote peer.
    case handshakeFailed
    
    /// Failed to encode a Codable value into binary format.
    ///
    /// Check that your type conforms to `Codable` and all properties
    /// are encodable. This may also indicate a BlazeBinary encoding issue.
    case encodingFailed
    
    /// Failed to decode binary data into the requested Codable type.
    ///
    /// Ensure the received data matches the expected type structure.
    /// This may indicate a protocol version mismatch or corrupted data.
    case decodingFailed
    
    /// A timeout occurred during a network operation.
    ///
    /// The operation exceeded the maximum allowed time. You may retry
    /// the operation or check network connectivity.
    case timeout
    
    /// An underlying system error occurred (wraps the original error).
    ///
    /// Contains the original error from the underlying system or network stack.
    /// Inspect the wrapped error for details.
    case underlying(Error)
}

// MARK: - Public Configuration Types

/// Security configuration for BlazeTransport connections.
///
/// BlazeTransport supports two security modes:
/// - `.blazeDefault`: Full encryption with X25519 key exchange and AEAD
/// - `.none`: No encryption (testing only, not for production)
///
/// ## Security Guarantees
///
/// When using `.blazeDefault`:
/// - All data is encrypted using ChaCha20-Poly1305 AEAD
/// - Perfect Forward Secrecy via ephemeral X25519 keys
/// - Replay protection via nonce management
/// - Automatic key rotation after 1M packets or 1 hour
///
/// - Since: 0.1.0
public enum BlazeSecurityConfig: Sendable {
    /// No encryption (for testing and development only).
    ///
    /// **Warning**: Never use in production. All data is transmitted in plaintext.
    case none
    
    /// Default Blaze security: X25519 key exchange + AEAD encryption via BlazeBinary.
    ///
    /// Provides industry-standard encryption equivalent to QUIC or TLS 1.3.
    /// Suitable for production use with proper application-level authentication.
    case blazeDefault
}

// MARK: - Public Statistics

/// Transport-level statistics for monitoring connection health and performance.
///
/// Use `BlazeConnection.stats()` to retrieve current statistics for monitoring,
/// debugging, and adaptive behavior based on network conditions.
///
/// ## Example
///
/// ```swift
/// let stats = await connection.stats()
/// if stats.lossRate > 0.05 {
///     print("High packet loss detected: \(stats.lossRate * 100)%")
/// }
/// if stats.roundTripTime > 0.1 {
///     print("High latency: \(stats.roundTripTime * 1000)ms")
/// }
/// ```
///
/// - Since: 0.1.0
public struct BlazeTransportStats: Sendable {
    /// Estimated round-trip time (RTT) in seconds.
    ///
    /// This is the smoothed RTT calculated using QUIC-style exponential moving average.
    /// Updated on each ACK received. Returns 0.0 if no RTT samples have been collected yet.
    ///
    /// Typical values:
    /// - Localhost: < 1ms
    /// - LAN: 1-10ms
    /// - Internet: 10-100ms
    /// - Satellite: 100-500ms
    public var roundTripTime: TimeInterval
    
    /// Current congestion window size in bytes.
    ///
    /// The congestion window limits the amount of unacknowledged data in flight.
    /// Grows during slow-start and congestion avoidance phases, decreases on packet loss.
    ///
    /// Typical values:
    /// - Initial: 1460 bytes (1 MSS)
    /// - Steady state: 10KB - 1MB (depends on RTT and bandwidth)
    public var congestionWindowBytes: Int
    
    /// Packet loss rate as a fraction between 0.0 and 1.0.
    ///
    /// Calculated as `lostPackets / sentPackets`. A value of 0.05 indicates 5% packet loss.
    ///
    /// Typical values:
    /// - Good network: < 0.01 (1%)
    /// - Normal network: 0.01 - 0.05 (1-5%)
    /// - Poor network: > 0.05 (5%+)
    public var lossRate: Double
    
    /// Total bytes sent on this connection since it was opened.
    ///
    /// Includes all application data, protocol headers, and retransmissions.
    public var bytesSent: Int
    
    /// Total bytes received on this connection since it was opened.
    ///
    /// Includes all application data and protocol headers.
    public var bytesReceived: Int

    /// Create transport statistics.
    ///
    /// - Parameters:
    ///   - roundTripTime: Estimated RTT in seconds
    ///   - congestionWindowBytes: Current congestion window size
    ///   - lossRate: Packet loss rate (0.0 to 1.0)
    ///   - bytesSent: Total bytes sent
    ///   - bytesReceived: Total bytes received
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

/// A connection to a remote host over BlazeTransport.
///
/// A `BlazeConnection` represents a single transport-layer connection that can
/// support multiple concurrent streams. Connections are established via
/// `BlazeTransport.connect()` and must be closed when done.
///
/// ## Thread Safety
///
/// `BlazeConnection` is safe to use from any Swift concurrency context.
/// All methods are `async` and can be called concurrently.
///
/// ## Example
///
/// ```swift
/// let connection = try await BlazeTransport.connect(
///     host: "example.com",
///     port: 9999
/// )
///
/// // Open multiple streams
/// let stream1 = try await connection.openStream()
/// let stream2 = try await connection.openStream()
///
/// // Use streams concurrently
/// async let task1 = stream1.send("Hello")
/// async let task2 = stream2.send("World")
/// try await task1
/// try await task2
///
/// // Close when done
/// try await connection.close()
/// ```
///
/// - Since: 0.1.0
public protocol BlazeConnection: Sendable {
    /// Open a new bidirectional stream on this connection.
    ///
    /// Each stream operates independently and can be used concurrently with other streams.
    /// Streams must be closed individually, and closing a connection closes all streams.
    ///
    /// - Returns: A new `BlazeStream` for sending and receiving data.
    /// - Throws: `BlazeTransportError.connectionClosed` if the connection is closed.
    /// - Note: Stream IDs are assigned automatically and increment sequentially.
    func openStream() async throws -> BlazeStream
    
    /// Close this connection and all its streams.
    ///
    /// After closing, the connection cannot be reused. All streams opened on this
    /// connection are automatically closed. Pending operations may be cancelled.
    ///
    /// - Throws: `BlazeTransportError` if closing fails (rare).
    /// - Note: It is safe to call `close()` multiple times.
    func close() async throws
    
    /// Get current connection statistics.
    ///
    /// Statistics are updated in real-time and reflect the current state of the connection.
    /// Use this for monitoring, debugging, and adaptive behavior.
    ///
    /// - Returns: Current `BlazeTransportStats` including RTT, congestion window, loss rate, and byte counts.
    /// - Note: Statistics are computed on-demand and may have slight latency.
    func stats() async -> BlazeTransportStats
}

/// A bidirectional stream for sending and receiving typed messages.
///
/// A `BlazeStream` represents a single data stream within a `BlazeConnection`.
/// Streams are independent: data sent on one stream does not block other streams,
/// and streams can be opened, used, and closed independently.
///
/// ## Type Safety
///
/// All messages must conform to `Codable`. The type system ensures that:
/// - You can only send `Codable` types
/// - You must specify the expected type when receiving
/// - Type mismatches are caught at compile time
///
/// ## Example
///
/// ```swift
/// struct Message: Codable {
///     let id: Int
///     let text: String
/// }
///
/// let stream = try await connection.openStream()
///
/// // Send a message
/// let message = Message(id: 1, text: "Hello")
/// try await stream.send(message)
///
/// // Receive a reply
/// let reply: Message = try await stream.receive(Message.self)
///
/// // Close the stream
/// try await stream.close()
/// ```
///
/// ## Thread Safety
///
/// `BlazeStream` is safe to use from any Swift concurrency context.
/// Multiple streams can be used concurrently on the same connection.
///
/// - Since: 0.1.0
public protocol BlazeStream: Sendable {
    /// Send a Codable value over this stream.
    ///
    /// The value is encoded using BlazeBinary before transmission. Encoding happens
    /// synchronously, but transmission is asynchronous and may be queued if the
    /// congestion window is full.
    ///
    /// - Parameter value: The value to send (must conform to `Codable` and `Sendable`).
    /// - Throws:
    ///   - `BlazeTransportError.connectionClosed` if the stream or connection is closed
    ///   - `BlazeTransportError.encodingFailed` if encoding fails
    ///   - `BlazeTransportError.timeout` if transmission times out
    /// - Note: Large values may be split across multiple packets automatically.
    func send<T: Codable & Sendable>(_ value: T) async throws
    
    /// Receive a Codable value from this stream.
    ///
    /// This method waits until data is available, then decodes it into the requested type.
    /// If the received data does not match the expected type, decoding fails.
    ///
    /// - Parameter type: The type to decode (must conform to `Codable` and `Sendable`).
    /// - Returns: The decoded value of the requested type.
    /// - Throws:
    ///   - `BlazeTransportError.connectionClosed` if the stream or connection is closed
    ///   - `BlazeTransportError.decodingFailed` if decoding fails or type mismatch
    ///   - `BlazeTransportError.timeout` if no data arrives within the timeout period
    /// - Note: This method blocks until data is available or the stream is closed.
    func receive<T: Codable & Sendable>(_ type: T.Type) async throws -> T
    
    /// Close this stream.
    ///
    /// After closing, the stream cannot be used for sending or receiving.
    /// The remote peer is notified of the stream closure. Closing a stream
    /// does not affect other streams on the same connection.
    ///
    /// - Throws: `BlazeTransportError` if closing fails (rare).
    /// - Note: It is safe to call `close()` multiple times.
    func close() async throws
}

// MARK: - Public API

/// Main entry point for BlazeTransport.
///
/// `BlazeTransport` provides a simple API for establishing connections to remote hosts.
/// All connections use UDP as the underlying transport and support multiple concurrent streams.
///
/// ## Example
///
/// ```swift
/// // Connect with default security
/// let connection = try await BlazeTransport.connect(
///     host: "example.com",
///     port: 9999
/// )
///
/// // Connect with explicit security configuration
/// let secureConnection = try await BlazeTransport.connect(
///     host: "example.com",
///     port: 9999,
///     security: .blazeDefault
/// )
/// ```
///
/// ## Connection Lifecycle
///
/// 1. **Connect**: Call `connect()` to establish a connection (performs cryptographic handshake)
/// 2. **Use**: Open streams and send/receive data
/// 3. **Close**: Call `close()` on the connection when done
///
/// - Since: 0.1.0
public enum BlazeTransport {
    /// Connect to a remote host over BlazeTransport.
    ///
    /// This method establishes a new transport connection to the specified host and port.
    /// The connection performs a cryptographic handshake (if security is enabled) before
    /// returning. Once connected, you can open streams and send/receive data.
    ///
    /// ## Handshake Process
    ///
    /// The connection handshake includes:
    /// - X25519 key exchange (if `.blazeDefault` security)
    /// - Cryptographic authentication
    /// - Connection ID establishment
    /// - Initial congestion window setup
    ///
    /// Handshake typically completes in 1-2 RTTs.
    ///
    /// ## Parameters
    ///
    /// - Parameter host: The hostname or IP address (e.g., "example.com" or "192.168.1.1")
    /// - Parameter port: The UDP port number (e.g., 9999)
    /// - Parameter security: Security configuration (defaults to `.blazeDefault`)
    ///
    /// ## Returns
    ///
    /// A connected `BlazeConnection` ready to use. The connection is fully established
    /// and authenticated (if security is enabled) before this method returns.
    ///
    /// ## Throws
    ///
    /// - `BlazeTransportError.handshakeFailed` if the cryptographic handshake fails
    /// - `BlazeTransportError.timeout` if connection establishment times out
    /// - `BlazeTransportError.underlying` for network or system errors
    ///
    /// ## Example
    ///
    /// ```swift
    /// do {
    ///     let connection = try await BlazeTransport.connect(
    ///         host: "example.com",
    ///         port: 9999,
    ///         security: .blazeDefault
    ///     )
    ///     // Connection is ready to use
    ///     let stream = try await connection.openStream()
    ///     // ...
    /// } catch BlazeTransportError.handshakeFailed {
    ///     print("Handshake failed - check security configuration")
    /// } catch {
    ///     print("Connection failed: \(error)")
    /// }
    /// ```
    ///
    /// - Since: 0.1.0
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
