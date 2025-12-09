import Foundation

/// Helper for calculating percentiles from latency histograms.
internal struct Percentile {
    /// Calculate percentile from sorted array of values.
    /// - Parameters:
    ///   - sorted: Sorted array of TimeInterval values
    ///   - p: Percentile (0.0 to 1.0)
    /// - Returns: Value at the given percentile
    static func calculate(_ sorted: [TimeInterval], _ p: Double) -> TimeInterval {
        guard !sorted.isEmpty else { return 0 }
        let index = Int(Double(sorted.count) * p)
        return sorted[min(index, sorted.count - 1)]
    }
    
    /// Calculate multiple percentiles at once.
    /// - Parameters:
    ///   - sorted: Sorted array of TimeInterval values
    ///   - percentiles: Array of percentile values (0.0 to 1.0)
    /// - Returns: Dictionary mapping percentile names to values
    static func calculateMultiple(_ sorted: [TimeInterval], percentiles: [Double]) -> [String: TimeInterval] {
        var results: [String: TimeInterval] = [:]
        for p in percentiles {
            let key = "p\(Int(p * 100))"
            results[key] = calculate(sorted, p)
        }
        return results
    }
    
    /// Calculate standard latency percentiles (p50, p90, p95, p99, max).
    static func standardLatency(_ sorted: [TimeInterval]) -> [String: TimeInterval] {
        var results: [String: TimeInterval] = [:]
        results["p50"] = calculate(sorted, 0.50)
        results["p90"] = calculate(sorted, 0.90)
        results["p95"] = calculate(sorted, 0.95)
        results["p99"] = calculate(sorted, 0.99)
        results["max"] = sorted.last ?? 0
        return results
    }
}

