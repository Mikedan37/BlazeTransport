import Foundation
import BlazeBinary

/// Default implementation of BlazeStream protocol.
/// Handles encoding/decoding of Codable types and delegates to ConnectionManager.
actor DefaultBlazeStream: BlazeStream {
    private let streamID: UInt32
    let connectionManager: ConnectionManager
    private var isClosed = false

    init(streamID: UInt32, connectionManager: ConnectionManager) {
        self.streamID = streamID
        self.connectionManager = connectionManager
    }

    /// Send a Codable value over this stream.
    /// The value is encoded using BlazeBinary before transmission.
    func send<T: Codable>(_ value: T) async throws {
        guard !isClosed else {
            throw BlazeTransportError.connectionClosed
        }

        do {
            let data = try BlazeBinaryHelpers.encode(value)
            try await connectionManager.send(data: data, on: streamID)
        } catch {
            throw BlazeTransportError.encodingFailed
        }
    }

    /// Receive a Codable value from this stream.
    /// The data is decoded using BlazeBinary after reception.
    func receive<T: Codable>(_ type: T.Type) async throws -> T {
        guard !isClosed else {
            throw BlazeTransportError.connectionClosed
        }

        let data = try await connectionManager.receive(on: streamID)
        
        do {
            return try BlazeBinaryHelpers.decode(type, from: data)
        } catch {
            throw BlazeTransportError.decodingFailed
        }
    }

    /// Close this stream.
    func close() async throws {
        guard !isClosed else { return }
        isClosed = true
        // Signal stream close to ConnectionManager
        await connectionManager.closeStream(streamID)
    }
}

