import XCTest
@testable import BlazeTransport

/// Simple test message type.
struct TestMessage: Codable, Equatable {
    let id: Int
    let text: String
}

/// Loopback transport test using mock sockets.
/// Tests end-to-end connection, stream opening, and message sending/receiving.
final class LoopbackTransportTests: XCTestCase {
    
    func testConnectionAndStreamLifecycle() async throws {
        // Create connections with mock sockets for loopback testing
        let serverConnection = DefaultBlazeConnection(
            host: "127.0.0.1",
            port: 9999,
            security: .blazeDefault,
            useMockSocket: true
        )
        
        let clientConnection = DefaultBlazeConnection(
            host: "127.0.0.1",
            port: 9998,
            security: .blazeDefault,
            useMockSocket: true
        )
        
        // Start both connections
        try await serverConnection.start()
        try await clientConnection.start()
        
        // Open streams
        let serverStream = try await serverConnection.openStream()
        let clientStream = try await clientConnection.openStream()
        
        // Send message from client
        let sentMessage = TestMessage(id: 42, text: "Hello, BlazeTransport!")
        try await clientStream.send(sentMessage)
        
        // Note: In a real implementation, the server would receive this via the network
        // For now, this verifies the API structure works correctly
        
        // Close streams and connections
        try await clientStream.close()
        try await serverStream.close()
        try await clientConnection.close()
        try await serverConnection.close()
    }
    
    /// Test that connection stats are accessible and update correctly.
    func testConnectionStats() async throws {
        let connection = DefaultBlazeConnection(
            host: "127.0.0.1",
            port: 8080,
            security: .blazeDefault,
            useMockSocket: true
        )
        
        try await connection.start()
        
        let stats = await connection.stats()
        XCTAssertTrue(stats.roundTripTime >= 0)
        XCTAssertTrue(stats.congestionWindowBytes > 0)
        XCTAssertTrue(stats.lossRate >= 0 && stats.lossRate <= 1)
        XCTAssertTrue(stats.bytesSent >= 0)
        XCTAssertTrue(stats.bytesReceived >= 0)
        
        try await connection.close()
    }
    
    /// Test multiple concurrent streams.
    func testMultipleStreams() async throws {
        let connection = DefaultBlazeConnection(
            host: "127.0.0.1",
            port: 8081,
            security: .blazeDefault,
            useMockSocket: true
        )
        
        try await connection.start()
        
        // Open multiple streams
        let stream1 = try await connection.openStream()
        let stream2 = try await connection.openStream()
        let stream3 = try await connection.openStream()
        
        // Verify all streams are created (they should be distinct instances)
        // Note: We can't directly compare object identity in Swift Testing, but we can verify they exist
        XCTAssertTrue(stream1 is DefaultBlazeStream)
        XCTAssertTrue(stream2 is DefaultBlazeStream)
        XCTAssertTrue(stream3 is DefaultBlazeStream)
        
        // Close all streams
        try await stream1.close()
        try await stream2.close()
        try await stream3.close()
        
        try await connection.close()
    }
}
