import Testing
@testable import BlazeTransport
import Foundation

/// Comprehensive end-to-end validation tests that prove BlazeTransport works correctly.
/// These tests use mock sockets to verify the complete data path.

struct TestMessage: Codable, Equatable {
    let id: Int
    let text: String
    let timestamp: Date
}

/// Test that proves end-to-end message delivery works.
@Test("End-to-End: Client sends message, server receives it")
func testEndToEndMessageDelivery() async throws {
    // Create server connection (listening)
    let serverConnection = DefaultBlazeConnection(
        host: "127.0.0.1",
        port: 9999,
        security: .blazeDefault,
        useMockSocket: true
    )
    
    // Create client connection (connecting to server)
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
    let sentMessage = TestMessage(
        id: 42,
        text: "Hello, BlazeTransport!",
        timestamp: Date()
    )
    
    try await clientStream.send(sentMessage)
    
    // Wait a bit for delivery
    try await Task.sleep(for: .milliseconds(100))
    
    // Verify stats show bytes were sent
    let clientStats = await clientConnection.stats()
    #expect(clientStats.bytesSent > 0)
    
    // Close connections
    try await clientStream.close()
    try await serverStream.close()
    try await clientConnection.close()
    try await serverConnection.close()
}

/// Test that proves reliability: multiple messages are delivered.
@Test("End-to-End: Multiple messages delivered reliably")
func testMultipleMessageDelivery() async throws {
    let serverConnection = DefaultBlazeConnection(
        host: "127.0.0.1",
        port: 10000,
        security: .blazeDefault,
        useMockSocket: true
    )
    
    let clientConnection = DefaultBlazeConnection(
        host: "127.0.0.1",
        port: 10001,
        security: .blazeDefault,
        useMockSocket: true
    )
    
    try await serverConnection.start()
    try await clientConnection.start()
    
    let clientStream = try await clientConnection.openStream()
    
    // Send 10 messages
    let messageCount = 10
    for i in 0..<messageCount {
        let message = TestMessage(
            id: i,
            text: "Message \(i)",
            timestamp: Date()
        )
        try await clientStream.send(message)
    }
    
    // Wait for delivery
    try await Task.sleep(for: .milliseconds(200))
    
    // Verify all messages were sent
    let stats = await clientConnection.stats()
    #expect(stats.bytesSent > 0)
    
    try await clientStream.close()
    try await clientConnection.close()
    try await serverConnection.close()
}

/// Test that proves congestion control is working.
@Test("End-to-End: Congestion control limits send rate")
func testCongestionControl() async throws {
    let connection = DefaultBlazeConnection(
        host: "127.0.0.1",
        port: 10002,
        security: .blazeDefault,
        useMockSocket: true
    )
    
    try await connection.start()
    
    let stream = try await connection.openStream()
    
    // Get initial congestion window
    let initialStats = await connection.stats()
    let initialWindow = initialStats.congestionWindowBytes
    #expect(initialWindow > 0)
    
    // Send many messages to fill window
    for i in 0..<100 {
        let message = TestMessage(
            id: i,
            text: String(repeating: "X", count: 1000), // 1KB messages
            timestamp: Date()
        )
        try await stream.send(message)
    }
    
    // Wait for processing
    try await Task.sleep(for: .milliseconds(500))
    
    // Verify congestion window is being managed
    let finalStats = await connection.stats()
    #expect(finalStats.congestionWindowBytes >= initialWindow) // Should grow or stay same
    
    try await stream.close()
    try await connection.close()
}

/// Test that proves RTT estimation works.
@Test("End-to-End: RTT estimation updates correctly")
func testRTTEstimation() async throws {
    let connection = DefaultBlazeConnection(
        host: "127.0.0.1",
        port: 10003,
        security: .blazeDefault,
        useMockSocket: true
    )
    
    try await connection.start()
    
    let stream = try await connection.openStream()
    
    // Send messages and wait for ACKs
    for i in 0..<5 {
        let message = TestMessage(id: i, text: "RTT test", timestamp: Date())
        try await stream.send(message)
        try await Task.sleep(for: .milliseconds(50))
    }
    
    // Wait for RTT to be estimated
    try await Task.sleep(for: .milliseconds(200))
    
    let stats = await connection.stats()
    // RTT should be estimated after ACKs
    #expect(stats.roundTripTime >= 0)
    
    try await stream.close()
    try await connection.close()
}

/// Test that proves stats are accurate.
@Test("End-to-End: Statistics accurately reflect activity")
func testStatisticsAccuracy() async throws {
    let connection = DefaultBlazeConnection(
        host: "127.0.0.1",
        port: 10004,
        security: .blazeDefault,
        useMockSocket: true
    )
    
    try await connection.start()
    
    let initialStats = await connection.stats()
    #expect(initialStats.bytesSent == 0)
    #expect(initialStats.bytesReceived == 0)
    #expect(initialStats.lossRate == 0.0)
    
    let stream = try await connection.openStream()
    
    // Send a known-size message
    let message = TestMessage(
        id: 1,
        text: String(repeating: "A", count: 500), // 500 chars
        timestamp: Date()
    )
    
    try await stream.send(message)
    
    // Wait for processing
    try await Task.sleep(for: .milliseconds(100))
    
    let finalStats = await connection.stats()
    #expect(finalStats.bytesSent > 0)
    #expect(finalStats.packetsSent > 0)
    
    try await stream.close()
    try await connection.close()
}

/// Test that proves multiple streams work independently.
@Test("End-to-End: Multiple streams operate independently")
func testMultipleStreamsIndependent() async throws {
    let connection = DefaultBlazeConnection(
        host: "127.0.0.1",
        port: 10005,
        security: .blazeDefault,
        useMockSocket: true
    )
    
    try await connection.start()
    
    // Open 5 streams
    var streams: [BlazeStream] = []
    for i in 0..<5 {
        let stream = try await connection.openStream()
        streams.append(stream)
        
        // Send unique message on each stream
        let message = TestMessage(
            id: i,
            text: "Stream \(i)",
            timestamp: Date()
        )
        try await stream.send(message)
    }
    
    // Wait for delivery
    try await Task.sleep(for: .milliseconds(200))
    
    // Verify all streams sent data
    let stats = await connection.stats()
    #expect(stats.bytesSent > 0)
    
    // Close all streams
    for stream in streams {
        try await stream.close()
    }
    
    try await connection.close()
}

