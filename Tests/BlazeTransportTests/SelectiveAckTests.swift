import XCTest
@testable import BlazeTransport

/// Tests for selective acknowledgment (SACK) functionality.
final class SelectiveAckTests: XCTestCase {
    
    func testSelectiveAckRanges() async throws {
        var reliability = ReliabilityEngine()
        
        // Send packets 1, 2, 3, 5, 6 (skip 4 to simulate loss)
        reliability.notePacketSent(1)
        reliability.notePacketSent(2)
        reliability.notePacketSent(3)
        reliability.notePacketSent(5)
        reliability.notePacketSent(6)
        
        // ACK packets 1, 2, 3 (contiguous range)
        reliability.noteAckReceived(for: 1)
        reliability.noteAckReceived(for: 2)
        reliability.noteAckReceived(for: 3)
        
        // ACK packets 5, 6 (another contiguous range)
        reliability.noteAckReceived(for: 5)
        reliability.noteAckReceived(for: 6)
        
        // Get ACK ranges
        let ranges = reliability.getAckRanges()
        XCTAssertTrue(ranges.count >= 2)  // Should have at least 2 ranges
        
        // Verify ranges cover the ACKed packets
        var ackedPackets: Set<UInt32> = []
        for range in ranges {
            for packetNum in range.start...range.end {
                ackedPackets.insert(packetNum)
            }
        }
        
        XCTAssertTrue(ackedPackets.contains(1))
        XCTAssertTrue(ackedPackets.contains(2))
        XCTAssertTrue(ackedPackets.contains(3))
        XCTAssertTrue(ackedPackets.contains(5))
        XCTAssertTrue(ackedPackets.contains(6))
    }
    
    func testIsAcked() async throws {
        var reliability = ReliabilityEngine()
        
        reliability.notePacketSent(10)
        reliability.notePacketSent(11)
        reliability.notePacketSent(12)
        
        XCTAssertFalse(reliability.isAcked(10))
        XCTAssertFalse(reliability.isAcked(11))
        XCTAssertFalse(reliability.isAcked(12))
        
        reliability.noteAckReceived(for: 10)
        reliability.noteAckReceived(for: 12)
        
        XCTAssertTrue(reliability.isAcked(10))
        XCTAssertFalse(reliability.isAcked(11))  // Not ACKed yet
        XCTAssertTrue(reliability.isAcked(12))
    }
    
    func testOutOfOrderAcks() async throws {
        var reliability = ReliabilityEngine()
        
        // ACK packets out of order
        reliability.noteAckReceived(for: 5)
        reliability.noteAckReceived(for: 3)
        reliability.noteAckReceived(for: 1)
        reliability.noteAckReceived(for: 2)
        reliability.noteAckReceived(for: 4)
        
        // After ACKing 1-5, should merge into single range
        let ranges = reliability.getAckRanges()
        // Should eventually merge into contiguous range 1-5
        XCTAssertTrue(ranges.count >= 1)
    }
}
