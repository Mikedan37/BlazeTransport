import Foundation
import BlazeTransport

/// Benchmarks for connection migration overhead.
internal struct MigrationBenchmarks {
    static func run() async -> [String: Any] {
        print("  Running connection migration benchmarks...")
        var results: [String: Any] = [:]
        
        // Migration validation overhead
        print("    Testing migration validation overhead...")
        let validationResults = await benchmarkMigrationValidation()
        results["migration_validation"] = validationResults
        
        // Address change detection
        print("    Testing address change detection...")
        let detectionResults = await benchmarkAddressChangeDetection()
        results["address_change_detection"] = detectionResults
        
        return results
    }
    
    private static func benchmarkMigrationValidation() async -> [String: Any] {
        let iterations = 1_000_000
        var migration = ConnectionMigration(host: "127.0.0.1", port: 9999)
        
        let startTime = Date()
        
        for _ in 0..<iterations {
            _ = migration.validateAddress(host: "127.0.0.1", port: 9999)
        }
        
        let elapsed = Date().timeIntervalSince(startTime)
        let opsPerSec = Double(iterations) / elapsed
        
        return [
            "iterations": iterations,
            "elapsed_seconds": elapsed,
            "ops_per_second": opsPerSec
        ]
    }
    
    private static func benchmarkAddressChangeDetection() async -> [String: Any] {
        let iterations = 1_000_000
        var migration = ConnectionMigration(host: "127.0.0.1", port: 9999)
        
        let startTime = Date()
        
        for i in 0..<iterations {
            let host = "192.168.1.\(i % 255)"
            let port = UInt16(10000 + (i % 1000))
            _ = migration.hasAddressChanged(host: host, port: port)
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

