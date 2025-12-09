import Testing
@testable import BlazeTransport

/// Tests for packet encoding and decoding.
@Test("PacketParser: encode then decode returns the same packet")
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
    
    #expect(decoded.header.version == originalPacket.header.version)
    #expect(decoded.header.flags == originalPacket.header.flags)
    #expect(decoded.header.connectionID == originalPacket.header.connectionID)
    #expect(decoded.header.packetNumber == originalPacket.header.packetNumber)
    #expect(decoded.header.streamID == originalPacket.header.streamID)
    #expect(decoded.header.payloadLength == originalPacket.header.payloadLength)
    #expect(decoded.payload == originalPacket.payload)
}

@Test("PacketParser: invalid lengths throw errors")
func testPacketParserInvalidLength() async throws {
    // Buffer too small
    let smallData = Data([1, 2, 3])
    #expect(throws: PacketParserError.bufferTooSmall) {
        try PacketParser.decode(smallData)
    }
    
    // Truncated payload
    var truncatedData = Data(count: PacketParser.headerSize)
    truncatedData[0] = 1 // version
    truncatedData[1] = 0 // flags
    // Set payloadLength to 100 but only provide header
    truncatedData[14] = 0
    truncatedData[15] = 100 // payloadLength = 100
    
    #expect(throws: PacketParserError.truncated) {
        try PacketParser.decode(truncatedData)
    }
}

@Test("PacketParser: big-endian encoding")
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
    #expect(decoded.header.connectionID == 0x12345678)
    #expect(decoded.header.packetNumber == 0xABCDEF00)
    #expect(decoded.header.streamID == 0x0000FFFF)
    #expect(decoded.header.payloadLength == 0x1234)
}

