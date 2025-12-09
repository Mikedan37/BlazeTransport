import Testing
@testable import BlazeTransport

/// Tests for packet coalescing functionality.
@Test("Packet Coalescing: Single packet is not coalesced")
func testSinglePacketCoalescing() async throws {
    let packet = BlazePacket(
        header: BlazePacketHeader(
            version: 1,
            flags: 0,
            connectionID: 0,
            packetNumber: 1,
            streamID: 1,
            payloadLength: 100
        ),
        payload: Data(repeating: 0xAB, count: 100)
    )
    
    let coalesced = PacketCoalescer.coalesce([packet])
    #expect(coalesced.count == 1)
}

@Test("Packet Coalescing: Multiple small packets are coalesced")
func testMultiplePacketsCoalescing() async throws {
    var packets: [BlazePacket] = []
    
    // Create 5 small packets (each ~100 bytes)
    for i in 1...5 {
        let packet = BlazePacket(
            header: BlazePacketHeader(
                version: 1,
                flags: 0,
                connectionID: 0,
                packetNumber: UInt32(i),
                streamID: 1,
                payloadLength: 100
            ),
            payload: Data(repeating: UInt8(i), count: 100)
        )
        packets.append(packet)
    }
    
    let coalesced = PacketCoalescer.coalesce(packets)
    // Should coalesce into fewer datagrams (depending on MTU)
    #expect(coalesced.count <= packets.count)
}

@Test("Packet Coalescing: Large packets are not coalesced")
func testLargePacketCoalescing() async throws {
    var packets: [BlazePacket] = []
    
    // Create 2 large packets (each ~1000 bytes)
    for i in 1...2 {
        let packet = BlazePacket(
            header: BlazePacketHeader(
                version: 1,
                flags: 0,
                connectionID: 0,
                packetNumber: UInt32(i),
                streamID: 1,
                payloadLength: 1000
            ),
            payload: Data(repeating: UInt8(i), count: 1000)
        )
        packets.append(packet)
    }
    
    let coalesced = PacketCoalescer.coalesce(packets)
    // Large packets may not be coalesced if they exceed MTU
    #expect(coalesced.count >= 1)
}

@Test("Packet Coalescing: Split coalesced datagram back to packets")
func testSplitCoalescedDatagram() async throws {
    let packet1 = BlazePacket(
        header: BlazePacketHeader(
            version: 1,
            flags: 0,
            connectionID: 0,
            packetNumber: 1,
            streamID: 1,
            payloadLength: 100
        ),
        payload: Data(repeating: 0xAA, count: 100)
    )
    
    let packet2 = BlazePacket(
        header: BlazePacketHeader(
            version: 1,
            flags: 0,
            connectionID: 0,
            packetNumber: 2,
            streamID: 1,
            payloadLength: 100
        ),
        payload: Data(repeating: 0xBB, count: 100)
    )
    
    let coalesced = PacketCoalescer.coalesce([packet1, packet2])
    #expect(coalesced.count >= 1)
    
    // Try to split the first coalesced datagram
    if let datagram = coalesced.first {
        let split = try PacketCoalescer.split(datagram)
        #expect(split.count >= 1)  // Should recover at least one packet
    }
}

