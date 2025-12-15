import Foundation
import BlazeTransport

/// Benchmarks for packet loss simulation and retransmission behavior.
/// Tests behavior under 1%, 5%, and 10% packet loss.
internal struct LossSimulation {
    static let lossRates: [Double] = [0.01, 0.05, 0.10] // 1%, 5%, 10%
    static let packetsToSend = 10000
    static let frameSize = 1024 // 1KB frames
    
    static func run(lossRate: Double? = nil) async -> [String: Any] {
        let ratesToTest = lossRate != nil ? [lossRate!] : lossRates
        
        print("  Running loss simulation benchmarks...")
        
        var results: [[String: Any]] = []
        
        for rate in ratesToTest {
            print("    Testing \(String(format: "%.1f", rate * 100))% packet loss...")
            
            var reliability = ReliabilityEngine()
            var congestion = CongestionController()
            var packetsSent = 0
            var packetsAcked = 0
            var retransmissions = 0
            var totalBytesSent = 0
            let startTime = Date()
            
            // Simulate sending packets with loss
            for i in 0..<packetsToSend {
                let packetNumber = reliability.allocatePacketNumber()
                reliability.notePacketSent(packetNumber)
                packetsSent += 1
                totalBytesSent += frameSize
                
                // Simulate loss
                let isLost = Double.random(in: 0...1) < rate
                
                if !isLost {
                    // Packet arrives, ACK received
                    reliability.noteAckReceived(for: packetNumber)
                    packetsAcked += 1
                    congestion.onAck(bytesAcked: frameSize)
                } else {
                    // Packet lost, will be retransmitted
                    retransmissions += 1
                    congestion.onLoss()
                }
            }
            
            // Calculate effective throughput (only successfully delivered bytes)
            let elapsed = Date().timeIntervalSince(startTime)
            let effectiveBytes = packetsAcked * frameSize
            let effectiveThroughputMBps = (Double(effectiveBytes) / elapsed) / (1024 * 1024)
            
            results.append([
                "loss_rate": rate,
                "packets_sent": packetsSent,
                "packets_acked": packetsAcked,
                "retransmissions": retransmissions,
                "effective_throughput_mbps": effectiveThroughputMBps,
                "congestion_window_bytes": congestion.congestionWindowBytes,
                "ssthresh": congestion.ssthresh,
                "rtt_estimate": reliability.rttEstimate ?? 0.0
            ])
            
            print("      Retransmissions: \(retransmissions), Effective Throughput: \(String(format: "%.2f", effectiveThroughputMBps)) MB/s")
        }
        
        return ["loss_rates": results]
    }
}

