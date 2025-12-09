/// Reliability engine for tracking packet transmission and RTT estimation.
/// Manages packet numbering, in-flight tracking, and round-trip time calculations.
/// Implements QUIC-style RTT estimation with smoothed RTT (srtt), RTT variance (rttvar), and minimum RTT.
import Foundation

/// ACK range for selective acknowledgment (SACK).
struct AckRange {
    let start: UInt32
    let end: UInt32
    
    var count: UInt32 {
        return end - start + 1
    }
}

/// Tracks packet reliability, acknowledgments, and RTT estimation.
internal struct ReliabilityEngine {
    private(set) var nextPacketNumber: UInt32 = 1
    var inFlight: [UInt32: Date] = [:]
    
    // QUIC-style RTT estimation (RFC 9002)
    private(set) var srtt: TimeInterval?  // Smoothed RTT
    private(set) var rttvar: TimeInterval?  // RTT variance
    private(set) var minRtt: TimeInterval?  // Minimum observed RTT
    
    // Selective ACK tracking
    private(set) var ackedRanges: [AckRange] = []
    private(set) var largestAcked: UInt32 = 0
    
    // Computed RTT estimate (for backward compatibility)
    var rttEstimate: TimeInterval? {
        guard let srtt = srtt else { return nil }
        // RTO = srtt + 4 * rttvar
        return srtt + (rttvar ?? 0) * 4
    }

    mutating func nextPacketNumber() -> UInt32 {
        let number = nextPacketNumber
        nextPacketNumber = nextPacketNumber &+ 1  // Wraps on overflow
        return number
    }

    mutating func notePacketSent(_ packetNumber: UInt32) {
        inFlight[packetNumber] = Date()
    }

    mutating func noteAckReceived(for packetNumber: UInt32) {
        guard let sendTime = inFlight.removeValue(forKey: packetNumber) else {
            return
        }

        let rtt = Date().timeIntervalSince(sendTime)
        updateRTT(rtt)
        updateAckedRanges(packetNumber)
    }
    
    /// Update RTT estimation using QUIC algorithm (RFC 9002).
    private mutating func updateRTT(_ rtt: TimeInterval) {
        // Update min_rtt
        if let currentMin = minRtt {
            minRtt = min(currentMin, rtt)
        } else {
            minRtt = rtt
        }
        
        // Initial RTT sample
        guard let currentSrtt = srtt, let currentRttvar = rttvar else {
            srtt = rtt
            rttvar = rtt / 2
            return
        }
        
        // Update smoothed RTT and variance
        let delta = abs(rtt - currentSrtt)
        rttvar = 0.75 * currentRttvar + 0.25 * delta
        srtt = 0.875 * currentSrtt + 0.125 * rtt
    }
    
    /// Update ACK ranges for selective acknowledgment.
    private mutating func updateAckedRanges(_ packetNumber: UInt32) {
        if packetNumber > largestAcked {
            largestAcked = packetNumber
        }
        
        // Merge with existing ranges or create new range
        var merged = false
        for i in 0..<ackedRanges.count {
            let range = ackedRanges[i]
            
            // Extend existing range
            if packetNumber == range.end + 1 {
                ackedRanges[i] = AckRange(start: range.start, end: packetNumber)
                merged = true
                break
            } else if packetNumber == range.start - 1 {
                ackedRanges[i] = AckRange(start: packetNumber, end: range.end)
                merged = true
                break
            } else if packetNumber >= range.start && packetNumber <= range.end {
                // Already in range
                merged = true
                break
            }
        }
        
        if !merged {
            ackedRanges.append(AckRange(start: packetNumber, end: packetNumber))
        }
        
        // Compress ranges (keep only last N ranges)
        if ackedRanges.count > 10 {
            ackedRanges = Array(ackedRanges.suffix(10))
        }
    }
    
    /// Get ACK ranges for selective acknowledgment frame.
    mutating func getAckRanges() -> [AckRange] {
        // Return compressed ranges (last 10 ranges)
        return Array(ackedRanges.suffix(10))
    }
    
    /// Check if a packet number has been acknowledged.
    func isAcked(_ packetNumber: UInt32) -> Bool {
        if packetNumber > largestAcked {
            return false
        }
        
        for range in ackedRanges {
            if packetNumber >= range.start && packetNumber <= range.end {
                return true
            }
        }
        return false
    }

    mutating func timedOutPackets(now: Date, timeout: TimeInterval) -> [UInt32] {
        let timeoutThreshold = now.addingTimeInterval(-timeout)
        var timedOut: [UInt32] = []

        for (packetNumber, sendTime) in inFlight {
            if sendTime < timeoutThreshold {
                // Skip if already acknowledged
                if !isAcked(packetNumber) {
                    timedOut.append(packetNumber)
                }
                inFlight.removeValue(forKey: packetNumber)
            }
        }

        return timedOut
    }
    
    /// Get retransmission timeout (RTO) based on RTT estimation.
    func getRTO() -> TimeInterval {
        guard let srtt = srtt else {
            return 1.0  // Default 1 second
        }
        
        let rttvar = self.rttvar ?? 0
        // RTO = srtt + 4 * rttvar, with minimum of 1ms
        return max(0.001, srtt + 4 * rttvar)
    }
}

