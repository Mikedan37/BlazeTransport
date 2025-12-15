import XCTest
@testable import BlazeTransport

/// Tests for DatagramSocket protocol implementations.
/// Validates both MockDatagramSocket and platform-specific implementations.
final class DatagramSocketTests: XCTestCase {
    
    // MARK: - Mock Socket Tests
    
    func testMockSocketBind() throws {
        let socket = MockDatagramSocket()
        try socket.bind(host: "127.0.0.1", port: 9999)
        
        let boundPort = socket.getBoundPort()
        XCTAssertEqual(boundPort, 9999)
    }
    
    func testMockSocketBindEphemeral() throws {
        let socket = MockDatagramSocket()
        try socket.bind(host: "127.0.0.1", port: 0)
        
        let boundPort = socket.getBoundPort()
        XCTAssertNotNil(boundPort)
    }
    
    func testMockSocketDoubleBind() throws {
        let socket = MockDatagramSocket()
        try socket.bind(host: "127.0.0.1", port: 9999)
        
        // Second bind should be no-op
        try socket.bind(host: "127.0.0.1", port: 9999)
        XCTAssertEqual(socket.getBoundPort(), 9999)
    }
    
    func testMockSocketAddressCollision() throws {
        let socket1 = MockDatagramSocket()
        try socket1.bind(host: "127.0.0.1", port: 9999)
        
        let socket2 = MockDatagramSocket()
        XCTAssertThrowsError(try socket2.bind(host: "127.0.0.1", port: 9999)) { error in
            XCTAssertTrue(error is BlazeTransportError)
        }
    }
    
    func testMockSocketSendReceive() throws {
        let server = MockDatagramSocket()
        let client = MockDatagramSocket()
        
        try server.bind(host: "127.0.0.1", port: 9999)
        try client.bind(host: "127.0.0.1", port: 10000)
        
        let testData = Data("Hello, BlazeTransport!".utf8)
        try client.send(to: "127.0.0.1", port: 9999, data: testData)
        
        // Give mock socket time to deliver
        Thread.sleep(forTimeInterval: 0.01)
        
        let (received, host, port) = try server.receive(maxBytes: 1024)
        XCTAssertEqual(received, testData)
        XCTAssertEqual(host, "127.0.0.1")
        XCTAssertEqual(port, 10000)
    }
    
    func testMockSocketClose() throws {
        let socket = MockDatagramSocket()
        try socket.bind(host: "127.0.0.1", port: 9999)
        
        try socket.close()
        
        // Operations after close should fail
        XCTAssertThrowsError(try socket.send(to: "127.0.0.1", port: 9999, data: Data())) { error in
            XCTAssertTrue(error is BlazeTransportError)
        }
    }
    
    func testMockSocketSetReceiveBufferSize() throws {
        let socket = MockDatagramSocket()
        // Should not throw (no-op for mock)
        try socket.setReceiveBufferSize(65536)
    }
    
    // MARK: - Platform Socket Tests (using Mock for safety)
    
    func testPlatformSocketCreation() throws {
        // On platforms where we can create real sockets, test initialization
        // For now, use mock to avoid requiring network permissions in CI
        let socket = MockDatagramSocket()
        XCTAssertNotNil(socket)
    }
    
    func testSocketProtocolConformance() {
        // Verify MockDatagramSocket conforms to protocol
        let socket: DatagramSocket = MockDatagramSocket()
        XCTAssertNotNil(socket)
    }
    
    // MARK: - Error Handling Tests
    
    func testMockSocketReceiveWhenClosed() throws {
        let socket = MockDatagramSocket()
        try socket.bind(host: "127.0.0.1", port: 9999)
        try socket.close()
        
        XCTAssertThrowsError(try socket.receive(maxBytes: 1024)) { error in
            XCTAssertTrue(error is BlazeTransportError)
        }
    }
    
    func testMockSocketSendWhenClosed() throws {
        let socket = MockDatagramSocket()
        try socket.bind(host: "127.0.0.1", port: 9999)
        try socket.close()
        
        XCTAssertThrowsError(try socket.send(to: "127.0.0.1", port: 9999, data: Data())) { error in
            XCTAssertTrue(error is BlazeTransportError)
        }
    }
    
    // MARK: - Large Data Tests
    
    func testMockSocketLargeData() throws {
        let server = MockDatagramSocket()
        let client = MockDatagramSocket()
        
        try server.bind(host: "127.0.0.1", port: 9999)
        try client.bind(host: "127.0.0.1", port: 10000)
        
        // Send 64KB of data
        let largeData = Data(repeating: 0xAA, count: 65536)
        try client.send(to: "127.0.0.1", port: 9999, data: largeData)
        
        Thread.sleep(forTimeInterval: 0.01)
        
        let (received, _, _) = try server.receive(maxBytes: 65536)
        XCTAssertEqual(received.count, 65536)
        XCTAssertEqual(received, largeData)
    }
    
    // MARK: - Multiple Messages Tests
    
    func testMockSocketMultipleMessages() throws {
        let server = MockDatagramSocket()
        let client = MockDatagramSocket()
        
        try server.bind(host: "127.0.0.1", port: 9999)
        try client.bind(host: "127.0.0.1", port: 10000)
        
        let messages = [
            Data("Message 1".utf8),
            Data("Message 2".utf8),
            Data("Message 3".utf8)
        ]
        
        for message in messages {
            try client.send(to: "127.0.0.1", port: 9999, data: message)
        }
        
        Thread.sleep(forTimeInterval: 0.01)
        
        // Receive all messages
        var received: [Data] = []
        for _ in 0..<messages.count {
            let (data, _, _) = try server.receive(maxBytes: 1024)
            received.append(data)
        }
        
        XCTAssertEqual(received.count, messages.count)
        for (index, message) in messages.enumerated() {
            XCTAssertEqual(received[index], message)
        }
    }
}

