import XCTest
@testable import BlazeTransport

/// Integration tests for backpressure and congestion handling.
/// Ensures large bursts cause congestion window reduction without crashes.
final class BackpressureTests: XCTestCase {
    
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
                congestion.onAck(bytesAcked: chunkSize, rtt: nil)
            }
        }
        
        // Window should have adjusted based on losses
        if losses > 0 {
            XCTAssertTrue(congestion.congestionWindowBytes < initialWindow * 2) // Should not grow unbounded
        }
        
        // Should not crash
        XCTAssertTrue(congestion.congestionWindowBytes > 0)
        XCTAssertTrue(congestion.ssthresh > 0)
    }
    
    func testBackpressureRecovery() async throws {
        var congestion = CongestionController(initialWindow: 1460, initialSsthresh: 65535)
        
        // Cause congestion with losses
        for _ in 0..<5 {
            congestion.onLoss()
        }
        
        let congestedWindow = congestion.congestionWindowBytes
        
        // Simulate recovery with successful ACKs
        for _ in 0..<20 {
            congestion.onAck(bytesAcked: 1460, rtt: nil)
        }
        
        // Window should recover (grow back)
        XCTAssertTrue(congestion.congestionWindowBytes >= congestedWindow)
        
        // Should not crash
        XCTAssertTrue(congestion.congestionWindowBytes > 0)
    }
    
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
            congestion.onAck(bytesAcked: 1460, rtt: nil)
        }
        }
        
        // Should still be in valid state
        XCTAssertTrue(congestion.congestionWindowBytes > 0)
        XCTAssertTrue(congestion.ssthresh > 0)
        XCTAssertTrue(reliability.allocatePacketNumber() > 0)
    }
}
