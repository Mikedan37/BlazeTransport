import XCTest
@testable import BlazeTransport

/// Tests for packet encoding and decoding.
final class PacketParserTests: XCTestCase {
    
    func testPacketParserRoundTrip() async throws {
        let originalPacket = BlazePacket(
            header: BlazePacketHeader(
                version: 1,
                flags: 2,
                connectionID: 12345,
                packetNumber: 67890,
                streamID: 111,
                payloadLength: 5
            ),
            payload: Data([1, 2, 3, 4, 5])
        )
        
        let encoded = PacketParser.encode(originalPacket)
        let decoded = try PacketParser.decode(encoded)
        
        XCTAssertEqual(decoded.header.version, originalPacket.header.version)
        XCTAssertEqual(decoded.header.flags, originalPacket.header.flags)
        XCTAssertEqual(decoded.header.connectionID, originalPacket.header.connectionID)
        XCTAssertEqual(decoded.header.packetNumber, originalPacket.header.packetNumber)
        XCTAssertEqual(decoded.header.streamID, originalPacket.header.streamID)
        XCTAssertEqual(decoded.header.payloadLength, originalPacket.header.payloadLength)
        XCTAssertEqual(decoded.payload, originalPacket.payload)
    }
    
    func testPacketParserInvalidLength() async throws {
        // Buffer too small
        let smallData = Data([1, 2, 3])
        XCTAssertThrowsError(try PacketParser.decode(smallData)) { error in
            XCTAssertTrue(error is PacketParserError)
            if let parserError = error as? PacketParserError {
                XCTAssertEqual(parserError, PacketParserError.bufferTooSmall)
            }
        }
        
        // Truncated payload
        var truncatedData = Data(count: PacketParser.headerSize)
        truncatedData[0] = 1 // version
        truncatedData[1] = 0 // flags
        // Set payloadLength to 100 but only provide header
        truncatedData[14] = 0
        truncatedData[15] = 100 // payloadLength = 100
        
        XCTAssertThrowsError(try PacketParser.decode(truncatedData)) { error in
            XCTAssertTrue(error is PacketParserError)
            if let parserError = error as? PacketParserError {
                XCTAssertEqual(parserError, PacketParserError.truncated)
            }
        }
    }
    
    func testPacketParserBigEndian() async throws {
        let packet = BlazePacket(
            header: BlazePacketHeader(
                version: 1,
                flags: 0,
                connectionID: 0x12345678,
                packetNumber: 0xABCDEF00,
                streamID: 0x0000FFFF,
                payloadLength: 0x1234
            ),
            payload: Data()
        )
        
        let encoded = PacketParser.encode(packet)
        let decoded = try PacketParser.decode(encoded)
        
        // Verify big-endian encoding
        XCTAssertEqual(decoded.header.connectionID, 0x12345678)
        XCTAssertEqual(decoded.header.packetNumber, 0xABCDEF00)
        XCTAssertEqual(decoded.header.streamID, 0x0000FFFF)
        XCTAssertEqual(decoded.header.payloadLength, 0x1234)
    }
}
