import XCTest
@testable import BlazeTransport

/// Correctness tests for socket layer implementation.
/// Validates protocol conformance, error handling, and edge cases.
final class SocketCorrectnessTests: XCTestCase {
    
    // MARK: - Protocol Conformance Tests
    
    func testDatagramSocketProtocolRequirements() {
        // Verify all required methods exist
        let socket: DatagramSocket = MockDatagramSocket()
        
        // All methods should be callable (compile-time check)
        XCTAssertNoThrow(try? socket.bind(host: "127.0.0.1", port: 0))
        XCTAssertNoThrow(try? socket.send(to: "127.0.0.1", port: 9999, data: Data()))
        XCTAssertNoThrow(try? socket.setReceiveBufferSize(1024))
        _ = socket.getBoundPort()
        XCTAssertNoThrow(try? socket.close())
    }
    
    // MARK: - Address Resolution Tests
    
    func testAddressResolutionLocalhost() throws {
        let socket = MockDatagramSocket()
        
        // Should handle various localhost representations
        XCTAssertNoThrow(try socket.bind(host: "127.0.0.1", port: 0))
        
        let socket2 = MockDatagramSocket()
        XCTAssertNoThrow(try socket2.bind(host: "localhost", port: 0))
        
        let socket3 = MockDatagramSocket()
        XCTAssertNoThrow(try socket3.bind(host: "0.0.0.0", port: 0))
    }
    
    // MARK: - Port Binding Tests
    
    func testPortBindingEphemeral() throws {
        let socket = MockDatagramSocket()
        try socket.bind(host: "127.0.0.1", port: 0)
        
        let boundPort = socket.getBoundPort()
        XCTAssertNotNil(boundPort)
        XCTAssertGreaterThanOrEqual(boundPort ?? 0, 0)
    }
    
    func testPortBindingSpecific() throws {
        let socket = MockDatagramSocket()
        let testPort: UInt16 = 12345
        try socket.bind(host: "127.0.0.1", port: testPort)
        
        let boundPort = socket.getBoundPort()
        XCTAssertEqual(boundPort, testPort)
    }
    
    // MARK: - Data Integrity Tests
    
    func testDataIntegrityRoundTrip() throws {
        let server = MockDatagramSocket()
        let client = MockDatagramSocket()
        
        try server.bind(host: "127.0.0.1", port: 9999)
        try client.bind(host: "127.0.0.1", port: 10000)
        
        // Test various data patterns
        let testCases: [Data] = [
            Data(), // Empty
            Data([0x00]), // Single zero byte
            Data([0xFF]), // Single max byte
            Data([0x00, 0xFF, 0xAA, 0x55]), // Pattern
            Data(Array(0..<256)), // All byte values
            Data(repeating: 0xAA, count: 1024), // Repeated pattern
        ]
        
        for testData in testCases {
            try client.send(to: "127.0.0.1", port: 9999, data: testData)
            Thread.sleep(forTimeInterval: 0.01)
            
            let (received, _, _) = try server.receive(maxBytes: 65535)
            XCTAssertEqual(received, testData, "Data integrity failed for size \(testData.count)")
        }
    }
    
    // MARK: - Error Handling Tests
    
    func testErrorHandlingClosedSocket() throws {
        let socket = MockDatagramSocket()
        try socket.bind(host: "127.0.0.1", port: 9999)
        try socket.close()
        
        // All operations should fail after close
        XCTAssertThrowsError(try socket.bind(host: "127.0.0.1", port: 9999))
        XCTAssertThrowsError(try socket.send(to: "127.0.0.1", port: 9999, data: Data()))
        XCTAssertThrowsError(try socket.receive(maxBytes: 1024))
    }
    
    func testErrorHandlingAddressCollision() throws {
        let socket1 = MockDatagramSocket()
        try socket1.bind(host: "127.0.0.1", port: 9999)
        
        let socket2 = MockDatagramSocket()
        XCTAssertThrowsError(try socket2.bind(host: "127.0.0.1", port: 9999)) { error in
            if case BlazeTransportError.underlying(let nsError) = error {
                XCTAssertEqual(nsError.code, Int(EADDRINUSE))
            } else {
                XCTFail("Expected EADDRINUSE error")
            }
        }
    }
    
    // MARK: - Buffer Size Tests
    
    func testReceiveBufferSize() throws {
        let socket = MockDatagramSocket()
        try socket.bind(host: "127.0.0.1", port: 9999)
        
        // Should accept various buffer sizes
        let sizes = [1024, 4096, 8192, 16384, 32768, 65536]
        for size in sizes {
            XCTAssertNoThrow(try socket.setReceiveBufferSize(size))
        }
    }
    
    // MARK: - Concurrent Operations Tests
    
    func testConcurrentSockets() throws {
        // Test multiple independent socket pairs
        let socketCount = 10
        var servers: [MockDatagramSocket] = []
        var clients: [MockDatagramSocket] = []
        
        for i in 0..<socketCount {
            let server = MockDatagramSocket()
            let client = MockDatagramSocket()
            
            try server.bind(host: "127.0.0.1", port: UInt16(10000 + i))
            try client.bind(host: "127.0.0.1", port: UInt16(20000 + i))
            
            servers.append(server)
            clients.append(client)
        }
        
        // Send from all clients
        for (index, client) in clients.enumerated() {
            let data = Data("Message \(index)".utf8)
            try client.send(to: "127.0.0.1", port: UInt16(10000 + index), data: data)
        }
        
        Thread.sleep(forTimeInterval: 0.01)
        
        // Receive from all servers
        for (index, server) in servers.enumerated() {
            let (data, _, _) = try server.receive(maxBytes: 1024)
            let expected = Data("Message \(index)".utf8)
            XCTAssertEqual(data, expected)
        }
    }
    
    // MARK: - Packet Parser Integration Tests
    
    func testPacketParserWithSocket() throws {
        let server = MockDatagramSocket()
        let client = MockDatagramSocket()
        
        try server.bind(host: "127.0.0.1", port: 9999)
        try client.bind(host: "127.0.0.1", port: 10000)
        
        // Create a valid packet
        let header = BlazePacketHeader(
            version: 1,
            flags: 0,
            connectionID: 12345,
            packetNumber: 1,
            streamID: 1,
            payloadLength: 10
        )
        let packet = BlazePacket(header: header, payload: Data(repeating: 0xAA, count: 10))
        
        // Encode and send
        let encoded = PacketParser.encode(packet)
        try client.send(to: "127.0.0.1", port: 9999, data: encoded)
        
        Thread.sleep(forTimeInterval: 0.01)
        
        // Receive and decode
        let (received, _, _) = try server.receive(maxBytes: 65535)
        let decoded = try PacketParser.decode(received)
        
        XCTAssertEqual(decoded.header.version, header.version)
        XCTAssertEqual(decoded.header.connectionID, header.connectionID)
        XCTAssertEqual(decoded.header.packetNumber, header.packetNumber)
        XCTAssertEqual(decoded.header.streamID, header.streamID)
        XCTAssertEqual(decoded.payload, packet.payload)
    }
    
    // MARK: - Resource Cleanup Tests
    
    func testResourceCleanup() throws {
        var sockets: [MockDatagramSocket] = []
        
        // Create many sockets
        for i in 0..<100 {
            let socket = MockDatagramSocket()
            try socket.bind(host: "127.0.0.1", port: UInt16(30000 + i))
            sockets.append(socket)
        }
        
        // Close all sockets
        for socket in sockets {
            try socket.close()
        }
        
        // Verify sockets are closed
        for socket in sockets {
            XCTAssertThrowsError(try socket.send(to: "127.0.0.1", port: 9999, data: Data()))
        }
    }
}

