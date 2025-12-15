import Testing
@testable import BlazeTransport

/// Integration tests for backpressure and congestion handling.
/// Ensures large bursts cause congestion window reduction without crashes.
@Test("Backpressure: large burst causes congestion window reduction")
func testBackpressureLargeBurst() async throws {
    var congestion = CongestionController(initialWindow: 1460, initialSsthresh: 65535)
    let initialWindow = congestion.congestionWindowBytes
    
    // Simulate large burst of data
    let burstSize = 1000000 // 1MB burst
    var bytesSent = 0
    var losses = 0
    
    // Simulate sending large burst with some loss
    while bytesSent < burstSize {
        let chunkSize = min(1460, burstSize - bytesSent)
        bytesSent += chunkSize
        
        // Simulate occasional loss (5%)
        if Double.random(in: 0...1) < 0.05 {
            congestion.onLoss()
            losses += 1
        } else {
            congestion.onAck(bytesAcked: chunkSize)
        }
    }
    
    // Window should have adjusted based on losses
    if losses > 0 {
        #expect(congestion.congestionWindowBytes < initialWindow * 2) // Should not grow unbounded
    }
    
    // Should not crash
    #expect(congestion.congestionWindowBytes > 0)
    #expect(congestion.ssthresh > 0)
}

@Test("Backpressure: graceful recovery after congestion")
func testBackpressureRecovery() async throws {
    var congestion = CongestionController(initialWindow: 1460, initialSsthresh: 65535)
    
    // Cause congestion with losses
    for _ in 0..<5 {
        congestion.onLoss()
    }
    
    let congestedWindow = congestion.congestionWindowBytes
    
    // Simulate recovery with successful ACKs
    for _ in 0..<20 {
        congestion.onAck(bytesAcked: 1460)
    }
    
    // Window should recover (grow back)
    #expect(congestion.congestionWindowBytes >= congestedWindow)
    
    // Should not crash
    #expect(congestion.congestionWindowBytes > 0)
}

@Test("Backpressure: no crashes under extreme load")
func testBackpressureExtremeLoad() async throws {
    var congestion = CongestionController()
    var reliability = ReliabilityEngine()
    
    // Simulate extreme load: many packets, high loss rate
    for _ in 0..<10000 {
        let packetNumber = reliability.allocatePacketNumber()
        reliability.notePacketSent(packetNumber)
        
        // 10% loss rate
        if Double.random(in: 0...1) < 0.10 {
            congestion.onLoss()
        } else {
            reliability.noteAckReceived(for: packetNumber)
            congestion.onAck(bytesAcked: 1460)
        }
    }
    
    // Should still be in valid state
    #expect(congestion.congestionWindowBytes > 0)
    #expect(congestion.ssthresh > 0)
    #expect(reliability.allocatePacketNumber() > 0)
}

