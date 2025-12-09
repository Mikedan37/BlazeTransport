import Foundation
import BlazeTransport

/// Benchmarks for congestion control and stream throughput under congestion.
internal struct CongestionBenchmarks {
    static func run() async -> [String: Any] {
        print("  Running congestion control benchmarks...")
        var results: [String: Any] = [:]
        
        // Stream throughput under congestion
        print("    Testing stream throughput under congestion...")
        let throughputResults = await benchmarkStreamThroughputUnderCongestion()
        results["stream_throughput_congestion"] = throughputResults
        
        // Congestion window growth
        print("    Testing congestion window growth...")
        let windowResults = await benchmarkCongestionWindowGrowth()
        results["congestion_window_growth"] = windowResults
        
        return results
    }
    
    private static func benchmarkStreamThroughputUnderCongestion() async -> [String: Any] {
        var throughputs: [Double] = []
        
        // Simulate different congestion levels
        for congestionLevel in [0, 1, 5, 10] {
            var congestion = CongestionController()
            
            // Simulate congestion by triggering losses
            for _ in 0..<congestionLevel {
                congestion.onLoss()
            }
            
            // Measure throughput with current window
            let windowSize = congestion.congestionWindowBytes
            let throughput = Double(windowSize) / 0.1  // Bytes per 100ms (simplified)
            throughputs.append(throughput)
        }
        
        return [
            "throughput_0_loss": throughputs[0],
            "throughput_1_loss": throughputs[1],
            "throughput_5_loss": throughputs[2],
            "throughput_10_loss": throughputs[3]
        ]
    }
    
    private static func benchmarkCongestionWindowGrowth() async -> [String: Any] {
        var windowSizes: [Int] = []
        var congestion = CongestionController()
        
        // Simulate ACKs and measure window growth
        for i in 0..<100 {
            congestion.onAck(bytesAcked: 1460, rtt: 0.01)
            if i % 10 == 0 {
                windowSizes.append(congestion.congestionWindowBytes)
            }
        }
        
        return [
            "initial_window": windowSizes.first ?? 0,
            "final_window": windowSizes.last ?? 0,
            "growth_rate": Double(windowSizes.last ?? 0) / Double(windowSizes.first ?? 1)
        ]
    }
}

