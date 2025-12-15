import XCTest
@testable import BlazeTransport

/// Fuzz tests specifically for PacketParser reliability.
/// Tests edge cases, boundary conditions, and malformed input handling.
final class PacketParserFuzzTests: XCTestCase {
    
    // MARK: - Boundary Value Tests
    
    func testPacketHeaderBoundaryValues() {
        // Test minimum values
        let minHeader = BlazePacketHeader(
            version: 0,
            flags: 0,
            connectionID: 0,
            packetNumber: 0,
            streamID: 0,
            payloadLength: 0
        )
        let minPacket = BlazePacket(header: minHeader, payload: Data())
        
        do {
            let encoded = PacketParser.encode(minPacket)
            let decoded = try PacketParser.decode(encoded)
            XCTAssertEqual(decoded.header.version, 0)
            XCTAssertEqual(decoded.header.payloadLength, 0)
        } catch {
            XCTFail("Failed to encode/decode minimum packet: \(error)")
        }
        
        // Test maximum values
        let maxHeader = BlazePacketHeader(
            version: 255,
            flags: 255,
            connectionID: UInt32.max,
            packetNumber: UInt32.max,
            streamID: UInt32.max,
            payloadLength: UInt16.max
        )
        let maxPayload = Data(repeating: 0xFF, count: Int(UInt16.max))
        let maxPacket = BlazePacket(header: maxHeader, payload: maxPayload)
        
        do {
            let encoded = PacketParser.encode(maxPacket)
            let decoded = try PacketParser.decode(encoded)
            XCTAssertEqual(decoded.header.version, 255)
            XCTAssertEqual(decoded.header.flags, 255)
            XCTAssertEqual(decoded.header.connectionID, UInt32.max)
            XCTAssertEqual(decoded.header.payloadLength, UInt16.max)
        } catch {
            XCTFail("Failed to encode/decode maximum packet: \(error)")
        }
    }
    
    // MARK: - Random Data Fuzzing
    
    func testFuzzRandomPacketData() {
        // Generate completely random packet data and verify parser handles it
        for _ in 0..<500 {
            let randomSize = Int.random(in: 0...2048)
            let randomData = Data((0..<randomSize).map { _ in UInt8.random(in: 0...255) })
            
            // Most random data should fail to parse (expected)
            let result = Result { try PacketParser.decode(randomData) }
            
            switch result {
            case .success(let packet):
                // If it parses, verify it can be re-encoded
                let reEncoded = PacketParser.encode(packet)
                XCTAssertGreaterThanOrEqual(reEncoded.count, PacketParser.headerSize)
            case .failure:
                // Expected for most random data
                break
            }
        }
    }
    
    func testFuzzValidPacketVariations() {
        // Generate valid packets with random but valid data
        for _ in 0..<1000 {
            let version = UInt8.random(in: 0...255)
            let flags = UInt8.random(in: 0...255)
            let connectionID = UInt32.random(in: 0...UInt32.max)
            let packetNumber = UInt32.random(in: 0...UInt32.max)
            let streamID = UInt32.random(in: 0...UInt32.max)
            let payloadSize = Int.random(in: 0...1024)
            let payload = Data((0..<payloadSize).map { _ in UInt8.random(in: 0...255) })
            
            let header = BlazePacketHeader(
                version: version,
                flags: flags,
                connectionID: connectionID,
                packetNumber: packetNumber,
                streamID: streamID,
                payloadLength: UInt16(payloadSize)
            )
            
            let packet = BlazePacket(header: header, payload: payload)
            
            // Should always encode/decode successfully
            do {
                let encoded = PacketParser.encode(packet)
                let decoded = try PacketParser.decode(encoded)
                
                XCTAssertEqual(decoded.header.version, version)
                XCTAssertEqual(decoded.header.flags, flags)
                XCTAssertEqual(decoded.header.connectionID, connectionID)
                XCTAssertEqual(decoded.header.packetNumber, packetNumber)
                XCTAssertEqual(decoded.header.streamID, streamID)
                XCTAssertEqual(decoded.header.payloadLength, UInt16(payloadSize))
                XCTAssertEqual(decoded.payload, payload)
            } catch {
                XCTFail("Failed to encode/decode valid packet: \(error)")
            }
        }
    }
    
    // MARK: - Corruption Tests
    
    func testFuzzSingleByteCorruption() {
        // Create valid packet
        let header = BlazePacketHeader(
            version: 1,
            flags: 0,
            connectionID: 12345,
            packetNumber: 1,
            streamID: 1,
            payloadLength: 10
        )
        let packet = BlazePacket(header: header, payload: Data(repeating: 0xAA, count: 10))
        let encoded = PacketParser.encode(packet)
        
        // Corrupt each byte one at a time
        for i in 0..<encoded.count {
            var corrupted = Data(encoded)
            corrupted[i] = corrupted[i] ^ 0xFF // Flip all bits
            
            // Should fail to decode
            XCTAssertThrowsError(try PacketParser.decode(corrupted)) { error in
                XCTAssertTrue(error is PacketParserError || error is BlazeTransportError)
            }
        }
    }
    
    func testFuzzPartialCorruption() {
        let header = BlazePacketHeader(
            version: 1,
            flags: 0,
            connectionID: 12345,
            packetNumber: 1,
            streamID: 1,
            payloadLength: 100
        )
        let packet = BlazePacket(header: header, payload: Data(repeating: 0xAA, count: 100))
        var encoded = PacketParser.encode(packet)
        
        // Corrupt random 10% of bytes
        let corruptionCount = encoded.count / 10
        for _ in 0..<corruptionCount {
            let index = Int.random(in: 0..<encoded.count)
            encoded[index] = UInt8.random(in: 0...255)
        }
        
        // Should fail to decode
        XCTAssertThrowsError(try PacketParser.decode(encoded)) { error in
            XCTAssertTrue(error is PacketParserError || error is BlazeTransportError)
        }
    }
    
    // MARK: - Size Mismatch Tests
    
    func testFuzzPayloadLengthMismatch() {
        // Create packet with mismatched payload length
        for _ in 0..<100 {
            let declaredLength = UInt16.random(in: 0...1024)
            let actualLength = Int.random(in: 0...1024)
            
            let header = BlazePacketHeader(
                version: 1,
                flags: 0,
                connectionID: 1,
                packetNumber: 1,
                streamID: 1,
                payloadLength: declaredLength
            )
            let payload = Data(repeating: 0xAA, count: actualLength)
            let packet = BlazePacket(header: header, payload: payload)
            
            // Encode the packet
            let encoded = PacketParser.encode(packet)
            
            // Manually corrupt the payload length field in the encoded data
            // Payload length is at offset 14 (after version, flags, connectionID, packetNumber, streamID)
            var corrupted = Data(encoded)
            if corrupted.count >= 16 {
                // Overwrite payload length with wrong value
                let wrongLength = UInt16.random(in: 0...UInt16.max)
                withUnsafeBytes(of: wrongLength.bigEndian) { bytes in
                    corrupted.replaceSubrange(14..<16, with: bytes)
                }
                
                // Should fail to decode or produce incorrect result
                let result = Result { try PacketParser.decode(corrupted) }
                switch result {
                case .success(let decoded):
                    // If it decodes, the length should be wrong (parser trusts the header)
                    XCTAssertEqual(decoded.header.payloadLength, wrongLength)
                case .failure:
                    // Expected - invalid length
                    break
                }
            }
        }
    }
    
    // MARK: - Endianness Tests
    
    func testFuzzEndiannessConsistency() {
        // Verify big-endian encoding is consistent
        for _ in 0..<100 {
            let connectionID = UInt32.random(in: 0...UInt32.max)
            let packetNumber = UInt32.random(in: 0...UInt32.max)
            let streamID = UInt32.random(in: 0...UInt32.max)
            
            let header = BlazePacketHeader(
                version: 1,
                flags: 0,
                connectionID: connectionID,
                packetNumber: packetNumber,
                streamID: streamID,
                payloadLength: 0
            )
            let packet = BlazePacket(header: header, payload: Data())
            
            let encoded = PacketParser.encode(packet)
            let decoded = try! PacketParser.decode(encoded)
            
            // Verify all multi-byte fields are correctly encoded/decoded
            XCTAssertEqual(decoded.header.connectionID, connectionID)
            XCTAssertEqual(decoded.header.packetNumber, packetNumber)
            XCTAssertEqual(decoded.header.streamID, streamID)
        }
    }
    
    // MARK: - Stress Tests
    
    func testFuzzRapidEncodeDecode() {
        // Rapid encode/decode cycles
        let header = BlazePacketHeader(
            version: 1,
            flags: 0,
            connectionID: 1,
            packetNumber: 1,
            streamID: 1,
            payloadLength: 100
        )
        let packet = BlazePacket(header: header, payload: Data(repeating: 0xAA, count: 100))
        
        for _ in 0..<10000 {
            let encoded = PacketParser.encode(packet)
            let decoded = try! PacketParser.decode(encoded)
            XCTAssertEqual(decoded.header.version, 1)
            XCTAssertEqual(decoded.payload.count, 100)
        }
    }
    
    func testFuzzMemorySafety() {
        // Test with various payload sizes to ensure no buffer overflows
        let sizes = [0, 1, 16, 256, 1024, 4096, 8192, 16384, 32768, 65535]
        
        for size in sizes {
            let header = BlazePacketHeader(
                version: 1,
                flags: 0,
                connectionID: 1,
                packetNumber: 1,
                streamID: 1,
                payloadLength: UInt16(size)
            )
            let payload = Data(repeating: 0xAA, count: size)
            let packet = BlazePacket(header: header, payload: payload)
            
            do {
                let encoded = PacketParser.encode(packet)
                let decoded = try PacketParser.decode(encoded)
                XCTAssertEqual(decoded.payload.count, size)
            } catch {
                XCTFail("Failed with size \(size): \(error)")
            }
        }
    }
}

