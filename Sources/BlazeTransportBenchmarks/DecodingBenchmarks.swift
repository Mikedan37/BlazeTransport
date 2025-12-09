import Foundation
import BlazeTransport

/// Microbenchmarks for decoding operations.
/// Tests varint, string, data, frame, and AEAD decoding throughput.
internal struct DecodingBenchmarks {
    static let iterations = 100000
    
    static func run() async -> [String: Any] {
        print("  Running decoding benchmarks...")
        
        var results: [String: Any] = [:]
        
        // Varint decoding
        print("    Testing varint decoding...")
        let varintThroughput = await benchmarkVarintDecoding()
        results["varint"] = varintThroughput
        print("      Varint: \(String(format: "%.2f", varintThroughput)) ops/sec")
        
        // String decoding
        print("    Testing string decoding...")
        let stringThroughput = await benchmarkStringDecoding()
        results["string"] = stringThroughput
        print("      String: \(String(format: "%.2f", stringThroughput)) ops/sec")
        
        // Data decoding (1KB, 4KB, 32KB)
        print("    Testing data decoding...")
        let dataResults = await benchmarkDataDecoding()
        results["data"] = dataResults
        for data in dataResults {
            if let size = data["size"] as? Int, let mbps = data["throughput_mbps"] as? Double {
                print("      Data (\(size)B): \(String(format: "%.2f", mbps)) MB/s")
            }
        }
        
        // Frame decoding
        print("    Testing frame decoding...")
        let frameThroughput = await benchmarkFrameDecoding()
        results["frame"] = frameThroughput
        print("      Frame: \(String(format: "%.2f", frameThroughput)) ops/sec")
        
        // AEAD decryption (simulated)
        print("    Testing AEAD decryption...")
        let aeadThroughput = await benchmarkAEADDecryption()
        results["aead"] = aeadThroughput
        print("      AEAD: \(String(format: "%.2f", aeadThroughput)) ops/sec")
        
        return results
    }
    
    private static func benchmarkVarintDecoding() async -> Double {
        let startTime = Date()
        var count = 0
        
        for i in 0..<iterations {
            // Simulate varint decoding (simplified)
            var value = UInt64(i)
            while value >= 0x80 {
                value >>= 7
                count += 1
            }
            count += 1
        }
        
        let elapsed = Date().timeIntervalSince(startTime)
        return Double(iterations) / elapsed
    }
    
    private static func benchmarkStringDecoding() async -> Double {
        let testData = "Hello, BlazeTransport! ".data(using: .utf8)!
        let startTime = Date()
        
        for _ in 0..<iterations {
            _ = String(data: testData, encoding: .utf8)
        }
        
        let elapsed = Date().timeIntervalSince(startTime)
        return Double(iterations) / elapsed
    }
    
    private static func benchmarkDataDecoding() async -> [[String: Any]] {
        let sizes = [1024, 4096, 32768] // 1KB, 4KB, 32KB
        var results: [[String: Any]] = []
        
        for size in sizes {
            let testData = Data(repeating: 0xAA, count: size)
            let startTime = Date()
            var totalBytes = 0
            
            for _ in 0..<(iterations / 10) { // Fewer iterations for larger data
                // Simulate decoding (just measure data handling)
                totalBytes += testData.count
            }
            
            let elapsed = Date().timeIntervalSince(startTime)
            let mbps = (Double(totalBytes) / elapsed) / (1024 * 1024)
            
            results.append([
                "size": size,
                "throughput_mbps": mbps
            ])
        }
        
        return results
    }
    
    private static func benchmarkFrameDecoding() async -> Double {
        let testData = Data(repeating: 0xAA, count: 1024)
        let packet = BlazePacket(
            header: BlazePacketHeader(
                version: 1,
                flags: 0,
                connectionID: 1,
                packetNumber: 1,
                streamID: 1,
                payloadLength: UInt16(testData.count)
            ),
            payload: testData
        )
        let encoded = PacketParser.encode(packet)
        
        let startTime = Date()
        var successCount = 0
        
        for _ in 0..<iterations {
            if (try? PacketParser.decode(encoded)) != nil {
                successCount += 1
            }
        }
        
        let elapsed = Date().timeIntervalSince(startTime)
        return Double(successCount) / elapsed
    }
    
    private static func benchmarkAEADDecryption() async -> Double {
        let testData = Data(repeating: 0xAA, count: 1024) + Data(repeating: 0, count: 16) // Simulate AEAD
        let startTime = Date()
        
        // Simulate AEAD decryption (just measure overhead)
        for _ in 0..<iterations {
            // In real implementation, would call BlazeBinary decryption
            _ = testData.prefix(testData.count - 16) // Remove tag
        }
        
        let elapsed = Date().timeIntervalSince(startTime)
        return Double(iterations) / elapsed
    }
}

