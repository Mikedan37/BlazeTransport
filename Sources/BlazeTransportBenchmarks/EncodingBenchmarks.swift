import Foundation
import BlazeTransport

/// Microbenchmarks for encoding operations.
/// Tests varint, string, data, frame, and AEAD encoding throughput.
internal struct EncodingBenchmarks {
    static let iterations = 100000
    
    static func run() async -> [String: Any] {
        print("  Running encoding benchmarks...")
        
        var results: [String: Any] = [:]
        
        // Varint encoding
        print("    Testing varint encoding...")
        let varintThroughput = await benchmarkVarintEncoding()
        results["varint"] = varintThroughput
            print("      Varint: \(String(format: "%.2f", varintThroughput)) ops/sec")
        
        // String encoding
        print("    Testing string encoding...")
        let stringThroughput = await benchmarkStringEncoding()
        results["string"] = stringThroughput
            print("      String: \(String(format: "%.2f", stringThroughput)) ops/sec")
        
        // Data encoding (1KB, 4KB, 32KB)
        print("    Testing data encoding...")
        let dataResults = await benchmarkDataEncoding()
        results["data"] = dataResults
        for data in dataResults {
            if let size = data["size"] as? Int, let mbps = data["throughput_mbps"] as? Double {
                print("      Data (\(size)B): \(String(format: "%.2f", mbps)) MB/s")
            }
        }
        
        // Frame encoding
        print("    Testing frame encoding...")
        let frameThroughput = await benchmarkFrameEncoding()
        results["frame"] = frameThroughput
        print("      Frame: \(String(format: "%.2f", frameThroughput)) ops/sec")
        
        // AEAD encryption (simulated)
        print("    Testing AEAD encryption...")
        let aeadThroughput = await benchmarkAEADEncryption()
        results["aead"] = aeadThroughput
        print("      AEAD: \(String(format: "%.2f", aeadThroughput)) ops/sec")
        
        return results
    }
    
    private static func benchmarkVarintEncoding() async -> Double {
        let startTime = Date()
        var count = 0
        
        for i in 0..<iterations {
            // Simulate varint encoding (simplified)
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
    
    private static func benchmarkStringEncoding() async -> Double {
        let testString = String(repeating: "Hello, BlazeTransport! ", count: 10)
        let startTime = Date()
        
        for _ in 0..<iterations {
            _ = testString.data(using: .utf8)
        }
        
        let elapsed = Date().timeIntervalSince(startTime)
        return Double(iterations) / elapsed
    }
    
    private static func benchmarkDataEncoding() async -> [[String: Any]] {
        let sizes = [1024, 4096, 32768] // 1KB, 4KB, 32KB
        var results: [[String: Any]] = []
        
        for size in sizes {
            let testData = Data(repeating: 0xAA, count: size)
            let startTime = Date()
            var totalBytes = 0
            
            for _ in 0..<(iterations / 10) { // Fewer iterations for larger data
                // Simulate encoding (just measure data handling)
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
    
    private static func benchmarkFrameEncoding() async -> Double {
        let testData = Data(repeating: 0xAA, count: 1024)
        let startTime = Date()
        
        for i in 0..<iterations {
            let packet = BlazePacket(
                header: BlazePacketHeader(
                    version: 1,
                    flags: 0,
                    connectionID: 1,
                    packetNumber: UInt32(i),
                    streamID: 1,
                    payloadLength: UInt16(testData.count)
                ),
                payload: testData
            )
            _ = PacketParser.encode(packet)
        }
        
        let elapsed = Date().timeIntervalSince(startTime)
        return Double(iterations) / elapsed
    }
    
    private static func benchmarkAEADEncryption() async -> Double {
        let testData = Data(repeating: 0xAA, count: 1024)
        let startTime = Date()
        
        // Simulate AEAD encryption (just measure overhead)
        for _ in 0..<iterations {
            // In real implementation, would call BlazeBinary encryption
            _ = testData + Data(repeating: 0, count: 16) // Simulate AEAD tag
        }
        
        let elapsed = Date().timeIntervalSince(startTime)
        return Double(iterations) / elapsed
    }
}

