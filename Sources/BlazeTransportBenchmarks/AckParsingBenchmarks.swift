import Foundation
import BlazeTransport

/// Benchmarks for ACK parsing performance.
internal struct AckParsingBenchmarks {
    static func run() async -> [String: Any] {
        print("  Running ACK parsing benchmarks...")
        var results: [String: Any] = [:]
        
        // ACK frame encoding/decoding
        print("    Testing ACK frame encoding/decoding...")
        let encodingResults = await benchmarkAckEncoding()
        results["ack_encoding"] = encodingResults
        
        // Selective ACK range processing
        print("    Testing selective ACK range processing...")
        let rangeResults = await benchmarkAckRangeProcessing()
        results["ack_range_processing"] = rangeResults
        
        return results
    }
    
    private static func benchmarkAckEncoding() async -> [String: Any] {
        let iterations = 100_000
        var reliability = ReliabilityEngine()
        
        // Generate ACK ranges
        for i in 1...100 {
            reliability.notePacketSent(UInt32(i))
            reliability.noteAckReceived(for: UInt32(i))
        }
        
        let startTime = Date()
        
        for _ in 0..<iterations {
            let ranges = reliability.getAckRanges()
            _ = ranges.count  // Simulate processing
        }
        
        let elapsed = Date().timeIntervalSince(startTime)
        let opsPerSec = Double(iterations) / elapsed
        
        return [
            "iterations": iterations,
            "elapsed_seconds": elapsed,
            "ops_per_second": opsPerSec
        ]
    }
    
    private static func benchmarkAckRangeProcessing() async -> [String: Any] {
        let iterations = 10_000
        var reliability = ReliabilityEngine()
        
        // Create complex ACK pattern (gaps)
        for i in 1...1000 {
            if i % 10 != 0 {  // Skip every 10th packet
                reliability.notePacketSent(UInt32(i))
                reliability.noteAckReceived(for: UInt32(i))
            }
        }
        
        let startTime = Date()
        
        for _ in 0..<iterations {
            let ranges = reliability.getAckRanges()
            for range in ranges {
                for packetNum in range.start...range.end {
                    _ = reliability.isAcked(packetNum)
                }
            }
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

