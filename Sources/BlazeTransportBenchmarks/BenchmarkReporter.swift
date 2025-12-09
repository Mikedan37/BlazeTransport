import Foundation

/// Reporter for exporting benchmark results to JSON and Markdown.
internal struct BenchmarkReporter {
    /// Export results to both JSON and Markdown formats.
    static func export(_ results: [String: Any], format: ExportFormat = .both) async {
        if format == .json || format == .both {
            await exportJSON(results)
        }
        if format == .markdown || format == .both {
            await exportMarkdown(results)
        }
    }
    
    /// Export results to JSON file.
    private static func exportJSON(_ results: [String: Any]) async {
        guard let jsonData = try? JSONSerialization.data(withJSONObject: results, options: [.prettyPrinted, .sortedKeys]) else {
            print("Warning: Failed to serialize JSON")
            return
        }
        
        let jsonString = String(data: jsonData, encoding: .utf8) ?? "{}"
        do {
            try jsonString.write(toFile: "benchmark_results.json", atomically: true, encoding: .utf8)
            print("Exported JSON to benchmark_results.json")
        } catch {
            print("Warning: Failed to write JSON: \(error)")
        }
    }
    
    /// Export results to Markdown file.
    private static func exportMarkdown(_ results: [String: Any]) async {
        var markdown = "# BlazeTransport Benchmark Results\n\n"
        markdown += "Generated: \(results["timestamp"] ?? "unknown")\n"
        markdown += "Total Time: \(String(format: "%.2f", results["total_time_seconds"] as? Double ?? 0))s\n\n"
        
        // Encoding benchmarks
        if let encoding = results["encoding"] as? [String: Any] {
            markdown += "## Encoding Benchmarks\n\n"
            markdown += generateEncodingTable(encoding)
        }
        
        // Decoding benchmarks
        if let decoding = results["decoding"] as? [String: Any] {
            markdown += "## Decoding Benchmarks\n\n"
            markdown += generateDecodingTable(decoding)
        }
        
        // Transport benchmarks
        if let transport = results["transport"] as? [String: Any] {
            markdown += "## Transport Benchmarks\n\n"
            markdown += generateTransportTable(transport)
        }
        
        // Loss simulation
        if let loss = results["loss_simulation"] as? [String: Any] {
            markdown += "## Loss Simulation Benchmarks\n\n"
            markdown += generateLossTable(loss)
        }
        
        // Stream scaling
        if let scaling = results["stream_scaling"] as? [String: Any] {
            markdown += "## Stream Scaling Benchmarks\n\n"
            markdown += generateScalingTable(scaling)
        }
        
        // Latency
        if let latency = results["latency"] as? [String: Any] {
            markdown += "## Latency Benchmarks\n\n"
            markdown += generateLatencyTable(latency)
        }
        
        do {
            try markdown.write(toFile: "benchmark_results.md", atomically: true, encoding: .utf8)
            print("Exported Markdown to benchmark_results.md")
        } catch {
            print("Warning: Failed to write Markdown: \(error)")
        }
    }
    
    private static func generateEncodingTable(_ encoding: [String: Any]) -> String {
        var table = "| Operation | Throughput (ops/sec) | MB/s |\n"
        table += "|-----------|----------------------|------|\n"
        
        if let varint = encoding["varint"] as? Double {
            table += "| Varint Encode | \(String(format: "%.2f", varint)) | - |\n"
        }
        if let string = encoding["string"] as? Double {
            table += "| String Encode | \(String(format: "%.2f", string)) | - |\n"
        }
        if let data = encoding["data"] as? [[String: Any]] {
            for d in data {
                let size = d["size"] as? Int ?? 0
                let throughput = d["throughput_mbps"] as? Double ?? 0
                table += "| Data Encode (\(size)B) | - | \(String(format: "%.2f", throughput)) |\n"
            }
        }
        if let frame = encoding["frame"] as? Double {
            table += "| Frame Encode | \(String(format: "%.2f", frame)) | - |\n"
        }
        if let aead = encoding["aead"] as? Double {
            table += "| AEAD Encrypt | \(String(format: "%.2f", aead)) | - |\n"
        }
        
        // Ensure all operations are included
        if encoding["varint"] == nil {
            table += "| Varint Encode | (not run) | - |\n"
        }
        if encoding["string"] == nil {
            table += "| String Encode | (not run) | - |\n"
        }
        if encoding["data"] == nil {
            table += "| Data Encode | (not run) | - |\n"
        }
        if encoding["frame"] == nil {
            table += "| Frame Encode | (not run) | - |\n"
        }
        if encoding["aead"] == nil {
            table += "| AEAD Encrypt | (not run) | - |\n"
        }
        
        return table + "\n"
    }
    
    private static func generateDecodingTable(_ decoding: [String: Any]) -> String {
        var table = "| Operation | Throughput (ops/sec) | MB/s |\n"
        table += "|-----------|----------------------|------|\n"
        
        if let varint = decoding["varint"] as? Double {
            table += "| Varint Decode | \(String(format: "%.2f", varint)) | - |\n"
        }
        if let string = decoding["string"] as? Double {
            table += "| String Decode | \(String(format: "%.2f", string)) | - |\n"
        }
        if let data = decoding["data"] as? [[String: Any]] {
            for d in data {
                let size = d["size"] as? Int ?? 0
                let throughput = d["throughput_mbps"] as? Double ?? 0
                table += "| Data Decode (\(size)B) | - | \(String(format: "%.2f", throughput)) |\n"
            }
        }
        if let frame = decoding["frame"] as? Double {
            table += "| Frame Decode | \(String(format: "%.2f", frame)) | - |\n"
        }
        if let aead = decoding["aead"] as? Double {
            table += "| AEAD Decrypt | \(String(format: "%.2f", aead)) | - |\n"
        }
        
        // Ensure all operations are included
        if decoding["varint"] == nil {
            table += "| Varint Decode | (not run) | - |\n"
        }
        if decoding["string"] == nil {
            table += "| String Decode | (not run) | - |\n"
        }
        if decoding["data"] == nil {
            table += "| Data Decode | (not run) | - |\n"
        }
        if decoding["frame"] == nil {
            table += "| Frame Decode | (not run) | - |\n"
        }
        if decoding["aead"] == nil {
            table += "| AEAD Decrypt | (not run) | - |\n"
        }
        
        return table + "\n"
    }
    
    private static func generateTransportTable(_ transport: [String: Any]) -> String {
        var table = "| Metric | Value |\n"
        table += "|--------|-------|\n"
        
        if let rtt = transport["rtt"] as? [String: Any] {
            table += "| RTT p50 | \(String(format: "%.2f", (rtt["p50"] as? Double ?? 0) * 1000))ms |\n"
            table += "| RTT p90 | \(String(format: "%.2f", (rtt["p90"] as? Double ?? 0) * 1000))ms |\n"
            table += "| RTT p95 | \(String(format: "%.2f", (rtt["p95"] as? Double ?? 0) * 1000))ms |\n"
            table += "| RTT p99 | \(String(format: "%.2f", (rtt["p99"] as? Double ?? 0) * 1000))ms |\n"
            table += "| RTT max | \(String(format: "%.2f", (rtt["max"] as? Double ?? 0) * 1000))ms |\n"
        } else {
            table += "| RTT p50 | (not run) |\n"
            table += "| RTT p90 | (not run) |\n"
            table += "| RTT p95 | (not run) |\n"
            table += "| RTT p99 | (not run) |\n"
            table += "| RTT max | (not run) |\n"
        }
        if let congestion = transport["congestion"] as? Double {
            table += "| Congestion Throughput | \(String(format: "%.2f", congestion)) MB/s |\n"
        } else {
            table += "| Congestion Throughput | (not run) |\n"
        }
        
        return table + "\n"
    }
    
    private static func generateLossTable(_ loss: [String: Any]) -> String {
        var table = "| Loss Rate | Retransmissions | Effective Throughput (MB/s) |\n"
        table += "|-----------|-----------------|----------------------------|\n"
        
        if let rates = loss["loss_rates"] as? [[String: Any]] {
            for rate in rates {
                let lossRate = rate["loss_rate"] as? Double ?? 0
                let retrans = rate["retransmissions"] as? Int ?? 0
                let throughput = rate["effective_throughput_mbps"] as? Double ?? 0
                table += "| \(String(format: "%.1f", lossRate * 100))% | \(retrans) | \(String(format: "%.2f", throughput)) |\n"
            }
        }
        
        return table + "\n"
    }
    
    private static func generateScalingTable(_ scaling: [String: Any]) -> String {
        var table = "| Streams | Throughput (MB/s) | Scaling Factor |\n"
        table += "|---------|-------------------|----------------|\n"
        
        if let streams = scaling["stream_counts"] as? [[String: Any]] {
            var baseline: Double? = nil
            for stream in streams.sorted(by: { ($0["stream_count"] as? Int ?? 0) < ($1["stream_count"] as? Int ?? 0) }) {
                let count = stream["stream_count"] as? Int ?? 0
                let throughput = stream["throughput_mbps"] as? Double ?? 0
                
                if baseline == nil && count == 1 {
                    baseline = throughput
                }
                
                let scalingFactor = baseline != nil && baseline! > 0 ? throughput / baseline! : 1.0
                table += "| \(count) | \(String(format: "%.2f", throughput)) | \(String(format: "%.2fx", scalingFactor)) |\n"
            }
        } else {
            // Include all expected stream counts even if not run
            for count in [1, 4, 8, 16, 32] {
                table += "| \(count) | (not run) | - |\n"
            }
        }
        
        return table + "\n"
    }
    
    private static func generateLatencyTable(_ latency: [String: Any]) -> String {
        var table = "| Percentile | RTT (ms) |\n"
        table += "|------------|----------|\n"
        
        let percentiles = ["p50", "p90", "p95", "p99", "max"]
        for p in percentiles {
            if let value = latency[p] as? Double {
                table += "| \(p) | \(String(format: "%.2f", value * 1000)) |\n"
            }
        }
        
        return table + "\n"
    }
}

enum ExportFormat {
    case json
    case markdown
    case both
}

