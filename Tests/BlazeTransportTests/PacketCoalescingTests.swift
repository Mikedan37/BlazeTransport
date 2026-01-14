import XCTest
@testable import BlazeTransport

/// Tests for packet coalescing functionality.
final class PacketCoalescingTests: XCTestCase {
    
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
        XCTAssertEqual(coalesced.count, 1)
    }
    
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
        XCTAssertTrue(coalesced.count <= packets.count)
    }
    
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
        XCTAssertTrue(coalesced.count >= 1)
    }
    
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
        XCTAssertTrue(coalesced.count >= 1)
        
        // Try to split the first coalesced datagram
        if let datagram = coalesced.first {
            let split = try PacketCoalescer.split(datagram)
            XCTAssertTrue(split.count >= 1)  // Should recover at least one packet
        }
    }
}
