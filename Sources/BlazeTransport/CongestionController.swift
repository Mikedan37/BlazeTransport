/// Congestion control using AIMD (Additive Increase Multiplicative Decrease).
/// Implements slow-start and congestion avoidance phases with QUIC-style improvements.
import Foundation

/// Pacing stub for future token bucket implementation.
struct PacingController {
    var tokens: Double = 0.0
    var lastUpdate: Date = Date()
    let rate: Double  // Bytes per second
    
    init(rate: Double = 1_000_000_000) { // 1 GB/s default (effectively unlimited)
        self.rate = rate
    }
    
    mutating func consume(bytes: Int, now: Date) -> Bool {
        let elapsed = now.timeIntervalSince(lastUpdate)
        tokens += rate * elapsed
        tokens = min(tokens, rate * 0.1) // Cap tokens to 100ms worth
        lastUpdate = now
        
        if tokens >= Double(bytes) {
            tokens -= Double(bytes)
            return true
        }
        return false
    }
}

/// Manages congestion window and implements AIMD algorithm with QUIC improvements.
public struct CongestionController {
    public private(set) var congestionWindowBytes: Int
    public private(set) var ssthresh: Int
    private(set) var pacing: PacingController
    
    // Loss detection state
    private var lossCount: Int = 0
    private var recoveryStartTime: Date?
    private var bytesInFlight: Int = 0

    public init(initialWindow: Int = 1460, initialSsthresh: Int = 65535) {
        self.congestionWindowBytes = initialWindow
        self.ssthresh = initialSsthresh
        self.pacing = PacingController()
    }

    public mutating func onAck(bytesAcked: Int, rtt: TimeInterval?) {
        bytesInFlight = max(0, bytesInFlight - bytesAcked)
        
        if congestionWindowBytes < ssthresh {
            // Slow start: exponential growth
            congestionWindowBytes += bytesAcked
        } else {
            // Congestion avoidance: linear growth
            // QUIC-style: increase by MSS * MSS / cwnd per ACK
            let mss = 1460
            let increment = (mss * mss) / max(1, congestionWindowBytes)
            congestionWindowBytes += increment
        }
        
        // Cap window to prevent overflow
        congestionWindowBytes = min(congestionWindowBytes, 10 * 1024 * 1024) // 10MB max
    }

    public mutating func onLoss() {
        // AIMD: cut window in half, update ssthresh
        ssthresh = max(congestionWindowBytes / 2, 1460)
        congestionWindowBytes = ssthresh
        lossCount += 1
        recoveryStartTime = Date()
    }
    
    /// Check if we can send bytes based on congestion window and pacing.
    mutating func canSend(bytes: Int, now: Date) -> Bool {
        // Check congestion window
        if bytesInFlight + bytes > congestionWindowBytes {
            return false
        }
        
        // Check pacing (stub - always allows for now)
        return pacing.consume(bytes: bytes, now: now)
    }
    
    /// Mark bytes as in-flight.
    mutating func markInFlight(bytes: Int) {
        bytesInFlight += bytes
    }
    
    /// Get current pacing rate.
    func getPacingRate() -> Double {
        return pacing.rate
    }
    
    /// Check if we're in recovery phase.
    func isInRecovery() -> Bool {
        return recoveryStartTime != nil
    }
}

