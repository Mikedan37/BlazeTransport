/// Reliability engine for tracking packet transmission and RTT estimation.
/// Manages packet numbering, in-flight tracking, and round-trip time calculations.
/// Implements QUIC-style RTT estimation with smoothed RTT (srtt), RTT variance (rttvar), and minimum RTT.
import Foundation

/// ACK range for selective acknowledgment (SACK).
public struct AckRange {
    public let start: UInt32
    public let end: UInt32

    var count: UInt32 {
        return end - start + 1
    }
}

/// Tracks packet reliability, acknowledgments, and RTT estimation.
public struct ReliabilityEngine {
    private(set) var nextPacketNumber: UInt32 = 1
    var inFlight: [UInt32: (sentAt: Date, packet: BlazePacket)] = [:]

    // QUIC-style RTT estimation (RFC 9002)
    public private(set) var srtt: TimeInterval?  // Smoothed RTT
    public private(set) var rttvar: TimeInterval?  // RTT variance
    private(set) var minRtt: TimeInterval?  // Minimum observed RTT

    // Selective ACK tracking
    private(set) var ackedRanges: [AckRange] = []
    private(set) var largestAcked: UInt32 = 0

    public init() {
        // All properties have default values
    }

    /// Smoothed round-trip time estimate.
    public var smoothedRTT: TimeInterval? {
        return srtt
    }

    /// Retransmission timeout (RTO) based on QUIC RFC 9002.
    public var rto: TimeInterval? {
        guard let srtt = srtt else { return nil }
        return srtt + (rttvar ?? 0) * 4
    }

    public mutating func allocatePacketNumber() -> UInt32 {
        let number = nextPacketNumber
        nextPacketNumber = nextPacketNumber &+ 1  // Wraps on overflow
        return number
    }

    public mutating func notePacketSent(_ packetNumber: UInt32, packet: BlazePacket) {
        inFlight[packetNumber] = (sentAt: Date(), packet: packet)
    }

    /// Convenience overload for tests and callers that don't need retransmission.
    public mutating func notePacketSent(_ packetNumber: UInt32) {
        let dummy = BlazePacket(
            header: BlazePacketHeader(version: 1, flags: 0, connectionID: 0, packetNumber: packetNumber, streamID: 0, payloadLength: 0),
            payload: Data()
        )
        notePacketSent(packetNumber, packet: dummy)
    }

    public mutating func noteAckReceived(for packetNumber: UInt32) {
        guard let entry = inFlight.removeValue(forKey: packetNumber) else {
            return
        }

        let rtt = Date().timeIntervalSince(entry.sentAt)
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

        // Coalesce adjacent/overlapping ranges
        coalesceRanges()

        // Compress ranges (keep only last N ranges)
        if ackedRanges.count > 10 {
            ackedRanges = Array(ackedRanges.suffix(10))
        }
    }

    /// Merge adjacent or overlapping ACK ranges.
    private mutating func coalesceRanges() {
        guard ackedRanges.count > 1 else { return }
        ackedRanges.sort { $0.start < $1.start }
        var merged: [AckRange] = [ackedRanges[0]]
        for i in 1..<ackedRanges.count {
            let current = ackedRanges[i]
            let last = merged[merged.count - 1]
            if current.start <= last.end + 1 {
                merged[merged.count - 1] = AckRange(start: last.start, end: max(last.end, current.end))
            } else {
                merged.append(current)
            }
        }
        ackedRanges = merged
    }

    /// Get ACK ranges for selective acknowledgment frame.
    public mutating func getAckRanges() -> [AckRange] {
        // Return compressed ranges (last 10 ranges)
        return Array(ackedRanges.suffix(10))
    }

    /// Check if a packet number has been acknowledged.
    public func isAcked(_ packetNumber: UInt32) -> Bool {
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

    mutating func timedOutPackets(now: Date, timeout: TimeInterval) -> [(packetNumber: UInt32, packet: BlazePacket)] {
        let timeoutThreshold = now.addingTimeInterval(-timeout)
        var timedOut: [(packetNumber: UInt32, packet: BlazePacket)] = []
        var keysToRemove: [UInt32] = []

        for (packetNumber, entry) in inFlight {
            if entry.sentAt < timeoutThreshold {
                if !isAcked(packetNumber) {
                    timedOut.append((packetNumber: packetNumber, packet: entry.packet))
                }
                keysToRemove.append(packetNumber)
            }
        }

        for key in keysToRemove {
            inFlight.removeValue(forKey: key)
        }

        return timedOut
    }

    /// Get retransmission timeout (RTO) based on RTT estimation.
    public func getRTO() -> TimeInterval {
        guard let srtt = srtt else {
            return 1.0  // Default 1 second
        }

        let rttvar = self.rttvar ?? 0
        // RTO = srtt + 4 * rttvar, with minimum of 1ms
        return max(0.001, srtt + 4 * rttvar)
    }
}
