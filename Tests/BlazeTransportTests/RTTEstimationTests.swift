import XCTest
@testable import BlazeTransport
import Foundation

/// Tests for RTT estimation using QUIC-style algorithm.
final class RTTEstimationTests: XCTestCase {
    
    func testInitialRTTSample() async throws {
        var reliability = ReliabilityEngine()
        
        XCTAssertNil(reliability.srtt)
        XCTAssertNil(reliability.rttvar)
        XCTAssertNil(reliability.minRtt)
        
        // First RTT sample
        reliability.notePacketSent(1)
        try await Task.sleep(for: .milliseconds(10))
        reliability.noteAckReceived(for: 1)
        
        XCTAssertNotNil(reliability.srtt)
        XCTAssertNotNil(reliability.rttvar)
        XCTAssertNotNil(reliability.minRtt)
        XCTAssertTrue(reliability.minRtt! > 0)
    }
    
    func testMultipleRTTSamples() async throws {
        var reliability = ReliabilityEngine()
        
        // Send and ACK multiple packets with different RTTs
        for i in 1...5 {
            reliability.notePacketSent(UInt32(i))
            try await Task.sleep(for: .milliseconds(10 + i))  // Increasing RTT
            reliability.noteAckReceived(for: UInt32(i))
        }
        
        XCTAssertNotNil(reliability.srtt)
        XCTAssertNotNil(reliability.rttvar)
        XCTAssertNotNil(reliability.minRtt)
        
        // srtt should be smoothed average
        if let srtt = reliability.srtt {
            XCTAssertTrue(srtt > 0.01)  // Should be around 10-15ms
            XCTAssertTrue(srtt < 0.1)   // Should be less than 100ms
        }
    }
    
    func testMinRttTracking() async throws {
        var reliability = ReliabilityEngine()
        
        // Send packets with varying RTTs
        reliability.notePacketSent(1)
        try await Task.sleep(for: .milliseconds(5))
        reliability.noteAckReceived(for: 1)
        
        let firstMinRtt = reliability.minRtt
        
        reliability.notePacketSent(2)
        try await Task.sleep(for: .milliseconds(20))
        reliability.noteAckReceived(for: 2)
        
        // minRtt should still be the smaller value
        XCTAssertNotNil(reliability.minRtt)
        XCTAssertTrue(reliability.minRtt! <= firstMinRtt! + 0.001)  // Should be close to first RTT
    }
    
    func testRTOCalculation() async throws {
        var reliability = ReliabilityEngine()
        
        reliability.notePacketSent(1)
        try await Task.sleep(for: .milliseconds(10))
        reliability.noteAckReceived(for: 1)
        
        let rto = reliability.getRTO()
        XCTAssertTrue(rto > 0)
        XCTAssertTrue(rto >= reliability.minRtt ?? 0)
        
        // RTO should be srtt + 4 * rttvar
        if let srtt = reliability.srtt, let rttvar = reliability.rttvar {
            let expectedRTO = srtt + 4 * rttvar
            XCTAssertTrue(abs(rto - expectedRTO) < 0.001)
        }
    }
}
