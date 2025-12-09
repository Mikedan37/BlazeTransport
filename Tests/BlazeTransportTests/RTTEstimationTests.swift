import Testing
@testable import BlazeTransport
import Foundation

/// Tests for RTT estimation using QUIC-style algorithm.
@Test("RTT Estimation: Initial RTT sample sets srtt and rttvar")
func testInitialRTTSample() async throws {
    var reliability = ReliabilityEngine()
    
    #expect(reliability.srtt == nil)
    #expect(reliability.rttvar == nil)
    #expect(reliability.minRtt == nil)
    
    // First RTT sample
    reliability.notePacketSent(1)
    try await Task.sleep(for: .milliseconds(10))
    reliability.noteAckReceived(for: 1)
    
    #expect(reliability.srtt != nil)
    #expect(reliability.rttvar != nil)
    #expect(reliability.minRtt != nil)
    #expect(reliability.minRtt! > 0)
}

@Test("RTT Estimation: Multiple samples update srtt and rttvar")
func testMultipleRTTSamples() async throws {
    var reliability = ReliabilityEngine()
    
    // Send and ACK multiple packets with different RTTs
    for i in 1...5 {
        reliability.notePacketSent(UInt32(i))
        try await Task.sleep(for: .milliseconds(10 + i))  // Increasing RTT
        reliability.noteAckReceived(for: UInt32(i))
    }
    
    #expect(reliability.srtt != nil)
    #expect(reliability.rttvar != nil)
    #expect(reliability.minRtt != nil)
    
    // srtt should be smoothed average
    if let srtt = reliability.srtt {
        #expect(srtt > 0.01)  // Should be around 10-15ms
        #expect(srtt < 0.1)   // Should be less than 100ms
    }
}

@Test("RTT Estimation: minRtt tracks minimum observed RTT")
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
    #expect(reliability.minRtt != nil)
    #expect(reliability.minRtt! <= firstMinRtt! + 0.001)  // Should be close to first RTT
}

@Test("RTT Estimation: RTO calculation uses srtt and rttvar")
func testRTOCalculation() async throws {
    var reliability = ReliabilityEngine()
    
    reliability.notePacketSent(1)
    try await Task.sleep(for: .milliseconds(10))
    reliability.noteAckReceived(for: 1)
    
    let rto = reliability.getRTO()
    #expect(rto > 0)
    #expect(rto >= reliability.minRtt ?? 0)
    
    // RTO should be srtt + 4 * rttvar
    if let srtt = reliability.srtt, let rttvar = reliability.rttvar {
        let expectedRTO = srtt + 4 * rttvar
        #expect(abs(rto - expectedRTO) < 0.001)
    }
}

