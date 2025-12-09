import Foundation
import BlazeTransport

/// Benchmarks for stream scaling performance.
/// Tests throughput with 1, 4, 8, 16, 32 concurrent streams.
internal struct StreamScaling {
    static let streamCounts: [Int] = [1, 4, 8, 16, 32]
    static let framesPerStream = 1000
    static let frameSize = 1024 // 1KB
    
    static func run(streamCount: Int? = nil) async -> [String: Any] {
        let countsToTest = streamCount != nil ? [streamCount!] : streamCounts
        
        print("  Running stream scaling benchmarks...")
        
        var results: [[String: Any]] = []
        
        for count in countsToTest {
            print("    Testing \(count) concurrent stream(s)...")
            
            let startTime = Date()
            var totalBytes = 0
            
            // Simulate concurrent streams
            await withTaskGroup(of: Int.self) { group in
                for streamID in 1...count {
                    group.addTask {
                        var bytes = 0
                        for _ in 0..<framesPerStream {
                            // Simulate packet creation and encoding
                            let packet = BlazePacket(
                                header: BlazePacketHeader(
                                    version: 1,
                                    flags: 0,
                                    connectionID: 1,
                                    packetNumber: UInt32.random(in: 1...UInt32.max),
                                    streamID: UInt32(streamID),
                                    payloadLength: UInt16(frameSize)
                                ),
                                payload: Data(repeating: 0xAA, count: frameSize)
                            )
                            let encoded = PacketParser.encode(packet)
                            bytes += encoded.count
                        }
                        return bytes
                    }
                }
                
                for await bytes in group {
                    totalBytes += bytes
                }
            }
            
            let elapsed = Date().timeIntervalSince(startTime)
            let throughputMBps = (Double(totalBytes) / elapsed) / (1024 * 1024)
            
            results.append([
                "stream_count": count,
                "frames_per_stream": framesPerStream,
                "total_bytes": totalBytes,
                "elapsed_seconds": elapsed,
                "throughput_mbps": throughputMBps
            ])
            
            print("      Throughput: \(String(format: "%.2f", throughputMBps)) MB/s")
        }
        
        return ["stream_counts": results]
    }
}

