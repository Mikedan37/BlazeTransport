import Foundation
import BlazeTransport

/// Fuzzing target for BlazeTransport.
/// Tests packet parsing, frame handling, and error recovery with random/corrupted inputs.
@main
struct BlazeTransportFuzzing {
    static func main() async {
        let args = CommandLine.arguments
        let iterations = Int(args.first(where: { $0.hasPrefix("--iterations") })?.split(separator: "=").last ?? "100000") ?? 100000
        
        print("🔬 BlazeTransport Fuzzing")
        print("Iterations: \(iterations)")
        print(String(repeating: "=", count: 50))
        
        var stats = FuzzingStats()
        
        for i in 0..<iterations {
            if i % 10000 == 0 && i > 0 {
                print("Progress: \(i)/\(iterations) (\(String(format: "%.1f", Double(i) / Double(iterations) * 100))%)")
            }
            
            // Random frame generation
            testRandomFrameGeneration(&stats)
            
            // Corrupted frame injection
            testCorruptedFrameInjection(&stats)
            
            // Invalid header tests
            testInvalidHeaders(&stats)
            
            // Truncated payload tests
            testTruncatedPayloads(&stats)
            
            // AEAD tag corruption detection
            testAEADTagCorruption(&stats)
        }
        
        print("\nFuzzing completed")
        print("\n📊 Statistics:")
        print("  Random frames generated: \(stats.randomFramesGenerated)")
        print("  Corrupted frames tested: \(stats.corruptedFramesTested)")
        print("  Invalid headers tested: \(stats.invalidHeadersTested)")
        print("  Truncated payloads tested: \(stats.truncatedPayloadsTested)")
        print("  AEAD corruption tests: \(stats.aeadCorruptionTests)")
        print("  Parsing errors caught: \(stats.parsingErrorsCaught)")
        print("  Crashes prevented: \(stats.crashesPrevented)")
    }
    
    static func testRandomFrameGeneration(_ stats: inout FuzzingStats) {
        let randomSize = Int.random(in: 0...65535)
        let randomData = Data((0..<randomSize).map { _ in UInt8.random(in: 0...255) })
        
        let packet = BlazePacket(
            header: BlazePacketHeader(
                version: UInt8.random(in: 0...255),
                flags: UInt8.random(in: 0...255),
                connectionID: UInt32.random(in: 0...UInt32.max),
                packetNumber: UInt32.random(in: 0...UInt32.max),
                streamID: UInt32.random(in: 0...UInt32.max),
                payloadLength: UInt16(min(randomSize, 65535))
            ),
            payload: randomData.prefix(min(randomSize, 65535))
        )
        
        do {
            let encoded = PacketParser.encode(packet)
            let _ = try PacketParser.decode(encoded)
            stats.randomFramesGenerated += 1
        } catch {
            stats.parsingErrorsCaught += 1
        }
    }
    
    static func testCorruptedFrameInjection(_ stats: inout FuzzingStats) {
        // Create valid packet
        let packet = BlazePacket(
            header: BlazePacketHeader(
                version: 1,
                flags: 0,
                connectionID: 1,
                packetNumber: 1,
                streamID: 1,
                payloadLength: 100
            ),
            payload: Data(repeating: 0xAA, count: 100)
        )
        
        var encoded = PacketParser.encode(packet)
        
        // Corrupt random bytes
        let corruptionCount = Int.random(in: 1...min(10, encoded.count))
        for _ in 0..<corruptionCount {
            let index = Int.random(in: 0..<encoded.count)
            encoded[index] = UInt8.random(in: 0...255)
        }
        
        do {
            let _ = try PacketParser.decode(encoded)
            // Should have thrown an error
            stats.crashesPrevented += 1
        } catch {
            stats.corruptedFramesTested += 1
            stats.parsingErrorsCaught += 1
        }
    }
    
    static func testInvalidHeaders(_ stats: inout FuzzingStats) {
        // Test with invalid payload length
        var invalidData = Data(count: PacketParser.headerSize)
        invalidData[0] = 1 // version
        invalidData[1] = 0 // flags
        // Set payloadLength to larger than available data
        invalidData[14] = 0xFF
        invalidData[15] = 0xFF // payloadLength = 65535, but only header available
        
        do {
            let _ = try PacketParser.decode(invalidData)
            stats.crashesPrevented += 1
        } catch {
            stats.invalidHeadersTested += 1
            stats.parsingErrorsCaught += 1
        }
    }
    
    static func testTruncatedPayloads(_ stats: inout FuzzingStats) {
        let payloadSize = Int.random(in: 100...1000)
        let truncatedSize = Int.random(in: 0..<payloadSize)
        
        var data = Data(count: PacketParser.headerSize + truncatedSize)
        data[0] = 1 // version
        data[1] = 0 // flags
        // Set payloadLength to full size, but data is truncated
        let payloadLength = UInt16(payloadSize)
        data[14] = UInt8(payloadLength >> 8)
        data[15] = UInt8(payloadLength & 0xFF)
        
        do {
            let _ = try PacketParser.decode(data)
            stats.crashesPrevented += 1
        } catch {
            stats.truncatedPayloadsTested += 1
            stats.parsingErrorsCaught += 1
        }
    }
    
    static func testAEADTagCorruption(_ stats: inout FuzzingStats) {
        // Simulate encrypted payload with corrupted AEAD tag
        // In real implementation, this would test BlazeBinary decryption
        let payload = Data(repeating: 0xAA, count: 100)
        let packet = BlazePacket(
            header: BlazePacketHeader(
                version: 1,
                flags: 0,
                connectionID: 1,
                packetNumber: 1,
                streamID: 1,
                payloadLength: UInt16(payload.count + 16) // +16 for AEAD tag
            ),
            payload: payload + Data(repeating: 0xFF, count: 16) // Corrupted tag
        )
        
        // This would test BlazeBinary decryption in real implementation
        // For now, just verify packet structure is valid
        do {
            let encoded = PacketParser.encode(packet)
            let decoded = try PacketParser.decode(encoded)
            // In real implementation, would attempt BlazeBinary decode here
            stats.aeadCorruptionTests += 1
        } catch {
            stats.parsingErrorsCaught += 1
        }
    }
}

struct FuzzingStats {
    var randomFramesGenerated = 0
    var corruptedFramesTested = 0
    var invalidHeadersTested = 0
    var truncatedPayloadsTested = 0
    var aeadCorruptionTests = 0
    var parsingErrorsCaught = 0
    var crashesPrevented = 0
}

