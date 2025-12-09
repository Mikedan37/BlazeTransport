import Foundation
import BlazeTransport

/// Main entry point for BlazeTransport benchmarks with CLI interface.
@main
struct BenchmarkMain {
    static func main() async {
        let args = CommandLine.arguments
        let config = parseArguments(args)
        
        print("BlazeTransport Benchmarks")
        print(String(repeating: "=", count: 50))
        print("Configuration: \(config.description)")
        print()
        
        var results: [String: Any] = [:]
        let startTime = Date()
        
        // Run benchmarks based on configuration
        if config.runAll || config.runEncoding {
            print("Running Encoding Benchmarks...")
            let encodingResults = await EncodingBenchmarks.run()
            results["encoding"] = encodingResults
            print()
        }
        
        if config.runAll || config.runDecoding {
            print("Running Decoding Benchmarks...")
            let decodingResults = await DecodingBenchmarks.run()
            results["decoding"] = decodingResults
            print()
        }
        
        if config.runAll || config.runTransport {
            print("Running Transport Benchmarks...")
            let transportResults = await TransportBenchmarks.run()
            results["transport"] = transportResults
            print()
        }
        
        if config.runAll || config.runCongestion {
            print("Running Congestion Benchmarks...")
            let congestionResults = await CongestionBenchmarks.run()
            results["congestion"] = congestionResults
            print()
        }
        
        if config.runAll || config.runAckParsing {
            print("Running ACK Parsing Benchmarks...")
            let ackResults = await AckParsingBenchmarks.run()
            results["ack_parsing"] = ackResults
            print()
        }
        
        if config.runAll || config.runRTT {
            print("Running RTT Benchmarks...")
            let rttResults = await RTTBenchmarks.run()
            results["rtt"] = rttResults
            print()
        }
        
        if config.runAll || config.runMigration {
            print("Running Migration Benchmarks...")
            let migrationResults = await MigrationBenchmarks.run()
            results["migration"] = migrationResults
            print()
        }
        
        if config.runAll || config.runLoss != nil {
            print("Running Loss Simulation Benchmarks...")
            let lossResults = await LossSimulation.run(lossRate: config.runLoss)
            results["loss_simulation"] = lossResults
            print()
        }
        
        if config.runAll || config.runStreams != nil {
            print("Running Stream Scaling Benchmarks...")
            let scalingResults = await StreamScaling.run(streamCount: config.runStreams)
            results["stream_scaling"] = scalingResults
            print()
        }
        
        if config.runAll || config.runCompetitive {
            print("Running Competitive Benchmarks...")
            let competitiveResults = await CompetitiveBenchmarks.run()
            results["competitive"] = competitiveResults
            print()
        }
        
        let totalTime = Date().timeIntervalSince(startTime)
        results["total_time_seconds"] = totalTime
        results["timestamp"] = ISO8601DateFormatter().string(from: Date())
        
        // Export results
        await BenchmarkReporter.export(results, format: config.exportFormat)
        
        print("\nBenchmarks completed in \(String(format: "%.2f", totalTime))s")
    }
    
    private static func parseArguments(_ args: [String]) -> BenchmarkConfig {
        var config = BenchmarkConfig()
        
        for arg in args {
            if arg == "--all" {
                config.runAll = true
            } else if arg == "--encoding" {
                config.runEncoding = true
            } else if arg == "--decoding" {
                config.runDecoding = true
            } else if arg == "--transport" {
                config.runTransport = true
            } else if arg.hasPrefix("--loss=") {
                let value = String(arg.dropFirst(7))
                config.runLoss = Double(value)
            } else if arg.hasPrefix("--streams=") {
                let value = String(arg.dropFirst(10))
                config.runStreams = Int(value)
            } else if arg == "--export=json" {
                config.exportFormat = .json
            } else if arg == "--export=markdown" {
                config.exportFormat = .markdown
            } else if arg == "--export=both" {
                config.exportFormat = .both
            } else if arg == "--competitive" {
                config.runCompetitive = true
            } else if arg == "--congestion" {
                config.runCongestion = true
            } else if arg == "--ack-parsing" {
                config.runAckParsing = true
            } else if arg == "--rtt" {
                config.runRTT = true
            } else if arg == "--migration" {
                config.runMigration = true
            }
        }
        
        // If no specific benchmarks selected, run all
        if !config.runAll && !config.runEncoding && !config.runDecoding && 
           !config.runTransport && config.runLoss == nil && config.runStreams == nil && 
           !config.runCompetitive && !config.runCongestion && !config.runAckParsing && 
           !config.runRTT && !config.runMigration {
            config.runAll = true
        }
        
        return config
    }
}

struct BenchmarkConfig {
    var runAll = false
    var runEncoding = false
    var runDecoding = false
    var runTransport = false
    var runLoss: Double? = nil
    var runStreams: Int? = nil
    var runCompetitive = false
    var runCongestion = false
    var runAckParsing = false
    var runRTT = false
    var runMigration = false
    var exportFormat: ExportFormat = .both
    
    var description: String {
        var parts: [String] = []
        if runAll {
            parts.append("all benchmarks")
        } else {
            if runEncoding { parts.append("encoding") }
            if runDecoding { parts.append("decoding") }
            if runTransport { parts.append("transport") }
            if let loss = runLoss { parts.append("loss=\(loss)") }
            if let streams = runStreams { parts.append("streams=\(streams)") }
        }
        parts.append("export=\(exportFormat)")
        return parts.joined(separator: ", ")
    }
}
