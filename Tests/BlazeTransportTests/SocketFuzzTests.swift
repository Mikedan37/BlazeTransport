import XCTest
@testable import BlazeTransport

/// Fuzz tests for socket layer reliability and error handling.
/// Tests edge cases, malformed data, and stress scenarios.
final class SocketFuzzTests: XCTestCase {
    
    // MARK: - Packet Encoding/Decoding Fuzz Tests
    
    func testFuzzPacketEncoding() {
        // Generate random packets and verify round-trip encoding/decoding
        for _ in 0..<1000 {
            let randomVersion = UInt8.random(in: 0...255)
            let randomFlags = UInt8.random(in: 0...255)
            let randomConnectionID = UInt32.random(in: 0...UInt32.max)
            let randomPacketNumber = UInt32.random(in: 1...UInt32.max)
            let randomStreamID = UInt32.random(in: 0...UInt32.max)
            
            let payloadSize = Int.random(in: 0...1024)
            let payload = Data((0..<payloadSize).map { _ in UInt8.random(in: 0...255) })
            
            let header = BlazePacketHeader(
                version: randomVersion,
                flags: randomFlags,
                connectionID: randomConnectionID,
                packetNumber: randomPacketNumber,
                streamID: randomStreamID,
                payloadLength: UInt16(payloadSize)
            )
            
            let packet = BlazePacket(header: header, payload: payload)
            
            // Encode and decode
            do {
                let encoded = PacketParser.encode(packet)
                let decoded = try PacketParser.decode(encoded)
                
                XCTAssertEqual(decoded.header.version, header.version)
                XCTAssertEqual(decoded.header.flags, header.flags)
                XCTAssertEqual(decoded.header.connectionID, header.connectionID)
                XCTAssertEqual(decoded.header.packetNumber, header.packetNumber)
                XCTAssertEqual(decoded.header.streamID, header.streamID)
                XCTAssertEqual(decoded.header.payloadLength, header.payloadLength)
                XCTAssertEqual(decoded.payload, payload)
            } catch {
                XCTFail("Failed to encode/decode packet: \(error)")
            }
        }
    }
    
    func testFuzzCorruptedPacketData() {
        // Test handling of corrupted packet data
        for _ in 0..<100 {
            let size = Int.random(in: 1...1024)
            var corruptedData = Data((0..<size).map { _ in UInt8.random(in: 0...255) })
            
            // Randomly corrupt some bytes
            let corruptionCount = Int.random(in: 1...min(10, size))
            for _ in 0..<corruptionCount {
                let index = Int.random(in: 0..<size)
                corruptedData[index] = UInt8.random(in: 0...255)
            }
            
            // Should handle corruption gracefully
            XCTAssertThrowsError(try PacketParser.decode(corruptedData)) { error in
                // Expected to throw PacketParserError
                XCTAssertTrue(error is PacketParserError || error is BlazeTransportError)
            }
        }
    }
    
    func testFuzzTruncatedPackets() {
        // Test handling of truncated packet data
        for _ in 0..<100 {
            // Create a valid packet
            let header = BlazePacketHeader(
                version: 1,
                flags: 0,
                connectionID: 1,
                packetNumber: 1,
                streamID: 1,
                payloadLength: 100
            )
            let packet = BlazePacket(header: header, payload: Data(repeating: 0xAA, count: 100))
            let encoded = PacketParser.encode(packet)
            
            // Truncate at random point
            let truncatePoint = Int.random(in: 1..<encoded.count)
            let truncated = encoded.prefix(truncatePoint)
            
            // Should throw error for truncated data
            XCTAssertThrowsError(try PacketParser.decode(truncated)) { error in
                XCTAssertTrue(error is PacketParserError || error is BlazeTransportError)
            }
        }
    }
    
    // MARK: - Socket Stress Tests
    
    func testSocketStressManyMessages() throws {
        let server = MockDatagramSocket()
        let client = MockDatagramSocket()
        
        try server.bind(host: "127.0.0.1", port: 9999)
        try client.bind(host: "127.0.0.1", port: 10000)
        
        let messageCount = 1000
        var sentCount = 0
        var receivedCount = 0
        
        // Send many messages rapidly
        for i in 0..<messageCount {
            let data = Data("Message \(i)".utf8)
            do {
                try client.send(to: "127.0.0.1", port: 9999, data: data)
                sentCount += 1
            } catch {
                // Some sends might fail under stress, that's okay
            }
        }
        
        // Receive as many as possible
        Thread.sleep(forTimeInterval: 0.1)
        
        while receivedCount < messageCount {
            do {
                let (data, _, _) = try server.receive(maxBytes: 1024)
                XCTAssertFalse(data.isEmpty)
                receivedCount += 1
            } catch {
                // No more data available
                break
            }
        }
        
        // Should receive at least some messages
        XCTAssertGreaterThan(receivedCount, 0)
        XCTAssertLessThanOrEqual(receivedCount, sentCount)
    }
    
    func testSocketStressLargePayloads() throws {
        let server = MockDatagramSocket()
        let client = MockDatagramSocket()
        
        try server.bind(host: "127.0.0.1", port: 9999)
        try client.bind(host: "127.0.0.1", port: 10000)
        
        // Test various large payload sizes
        let sizes = [1024, 4096, 8192, 16384, 32768, 65535]
        
        for size in sizes {
            let largeData = Data(repeating: UInt8.random(in: 0...255), count: size)
            
            try client.send(to: "127.0.0.1", port: 9999, data: largeData)
            Thread.sleep(forTimeInterval: 0.01)
            
            let (received, _, _) = try server.receive(maxBytes: size)
            XCTAssertEqual(received.count, size)
            XCTAssertEqual(received, largeData)
        }
    }
    
    // MARK: - Edge Case Tests
    
    func testEmptyPayload() throws {
        let server = MockDatagramSocket()
        let client = MockDatagramSocket()
        
        try server.bind(host: "127.0.0.1", port: 9999)
        try client.bind(host: "127.0.0.1", port: 10000)
        
        let emptyData = Data()
        try client.send(to: "127.0.0.1", port: 9999, data: emptyData)
        
        Thread.sleep(forTimeInterval: 0.01)
        
        let (received, _, _) = try server.receive(maxBytes: 1024)
        XCTAssertEqual(received.count, 0)
    }
    
    func testMaxUDPPayload() throws {
        // UDP max payload is typically 65507 bytes (65535 - 8 byte UDP header - 20 byte IP header)
        // But we'll test with 65535 as maxBytes parameter
        let server = MockDatagramSocket()
        let client = MockDatagramSocket()
        
        try server.bind(host: "127.0.0.1", port: 9999)
        try client.bind(host: "127.0.0.1", port: 10000)
        
        let maxData = Data(repeating: 0xFF, count: 65535)
        try client.send(to: "127.0.0.1", port: 9999, data: maxData)
        
        Thread.sleep(forTimeInterval: 0.01)
        
        let (received, _, _) = try server.receive(maxBytes: 65535)
        XCTAssertEqual(received.count, 65535)
    }
    
    func testConcurrentSockets() throws {
        // Test multiple socket pairs operating concurrently
        let socketPairs = (0..<10).map { _ in
            (server: MockDatagramSocket(), client: MockDatagramSocket())
        }
        
        for (index, pair) in socketPairs.enumerated() {
            let port = UInt16(10000 + index)
            try pair.server.bind(host: "127.0.0.1", port: port)
            try pair.client.bind(host: "127.0.0.1", port: UInt16(20000 + index))
        }
        
        // Send from all clients
        for (index, pair) in socketPairs.enumerated() {
            let data = Data("Message from client \(index)".utf8)
            try pair.client.send(to: "127.0.0.1", port: UInt16(10000 + index), data: data)
        }
        
        Thread.sleep(forTimeInterval: 0.01)
        
        // Receive from all servers
        for (index, pair) in socketPairs.enumerated() {
            let (data, _, _) = try pair.server.receive(maxBytes: 1024)
            let expected = Data("Message from client \(index)".utf8)
            XCTAssertEqual(data, expected)
        }
    }
    
    // MARK: - Address Resolution Tests
    
    func testLocalhostAddresses() throws {
        // Test various localhost representations
        let addresses = ["127.0.0.1", "localhost", "0.0.0.0"]
        
        for address in addresses {
            let testSocket = MockDatagramSocket()
            // Should not throw for valid localhost addresses
            XCTAssertNoThrow(try testSocket.bind(host: address, port: 0))
        }
    }
    
    // MARK: - Buffer Size Tests
    
    func testReceiveBufferSize() throws {
        let socket = MockDatagramSocket()
        try socket.bind(host: "127.0.0.1", port: 9999)
        
        // Test various buffer sizes
        let sizes = [1024, 4096, 8192, 16384, 32768, 65536]
        
        for size in sizes {
            XCTAssertNoThrow(try socket.setReceiveBufferSize(size))
        }
    }
    
    // MARK: - Error Recovery Tests
    
    func testSocketReuseAfterError() throws {
        let socket = MockDatagramSocket()
        
        // Bind and close
        try socket.bind(host: "127.0.0.1", port: 9999)
        try socket.close()
        
        // Create new socket (simulating recovery)
        let newSocket = MockDatagramSocket()
        XCTAssertNoThrow(try newSocket.bind(host: "127.0.0.1", port: 9999))
    }
}

