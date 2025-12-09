import Foundation
import BlazeTransport

/// Benchmarks for RTT estimation overhead.
internal struct RTTBenchmarks {
    static func run() async -> [String: Any] {
        print("  Running RTT estimation benchmarks...")
        var results: [String: Any] = [:]
        
        // RTT update overhead
        print("    Testing RTT update overhead...")
        let updateResults = await benchmarkRTTUpdate()
        results["rtt_update"] = updateResults
        
        // RTO calculation overhead
        print("    Testing RTO calculation overhead...")
        let rtoResults = await benchmarkRTOCalculation()
        results["rto_calculation"] = rtoResults
        
        return results
    }
    
    private static func benchmarkRTTUpdate() async -> [String: Any] {
        let iterations = 1_000_000
        var reliability = ReliabilityEngine()
        
        let startTime = Date()
        
        for i in 0..<iterations {
            let packetNum = UInt32(i % 1000) + 1
            reliability.notePacketSent(packetNum)
            
            // Simulate RTT sample
            let rtt = Double.random(in: 0.001...0.1)  // 1ms to 100ms
            // Note: In real implementation, RTT comes from timing
            // For benchmark, we'll simulate by directly calling noteAckReceived
            reliability.noteAckReceived(for: packetNum)
        }
        
        let elapsed = Date().timeIntervalSince(startTime)
        let opsPerSec = Double(iterations) / elapsed
        
        return [
            "iterations": iterations,
            "elapsed_seconds": elapsed,
            "ops_per_second": opsPerSec,
            "final_srtt": reliability.srtt ?? 0,
            "final_rttvar": reliability.rttvar ?? 0
        ]
    }
    
    private static func benchmarkRTOCalculation() async -> [String: Any] {
        let iterations = 10_000_000
        var reliability = ReliabilityEngine()
        
        // Initialize RTT
        reliability.notePacketSent(1)
        reliability.noteAckReceived(for: 1)
        
        let startTime = Date()
        
        for _ in 0..<iterations {
            _ = reliability.getRTO()
        }
        
        let elapsed = Date().timeIntervalSince(startTime)
        let opsPerSec = Double(iterations) / elapsed
        
        return [
            "iterations": iterations,
            "elapsed_seconds": elapsed,
            "ops_per_second": opsPerSec
        ]
    }
}

