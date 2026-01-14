/// Packet coalescing: combines multiple packets into a single UDP datagram.
/// Reduces UDP overhead by batching packets when MTU permits.
import Foundation

/// Coalesces multiple BlazePackets into a single UDP datagram when possible.
internal struct PacketCoalescer {
    static let maxMTU = 1500  // Standard Ethernet MTU
    static let ipHeaderSize = 20  // IPv4 header
    static let udpHeaderSize = 8  // UDP header
    static let maxPayloadSize = maxMTU - ipHeaderSize - udpHeaderSize  // ~1472 bytes
    
    /// Coalesce packets into a single datagram if MTU permits.
    /// Returns array of Data (each Data is a coalesced datagram or single packet).
    static func coalesce(_ packets: [BlazePacket]) -> [Data] {
        var result: [Data] = []
        var currentBatch: [BlazePacket] = []
        var currentSize = 0
        
        for packet in packets {
            let packetData = PacketParser.encode(packet)
            let packetSize = packetData.count
            
            // Check if adding this packet would exceed MTU
            if currentSize + packetSize > maxPayloadSize && !currentBatch.isEmpty {
                // Flush current batch
                result.append(combinePackets(currentBatch))
                currentBatch = [packet]
                currentSize = packetSize
            } else {
                // Add to current batch
                currentBatch.append(packet)
                currentSize += packetSize
            }
        }
        
        // Flush remaining batch
        if !currentBatch.isEmpty {
            result.append(combinePackets(currentBatch))
        }
        
        return result
    }
    
    /// Combine multiple packets into a single datagram.
    private static func combinePackets(_ packets: [BlazePacket]) -> Data {
        var combined = Data()
        
        // For simplicity, just concatenate encoded packets
        // In a full implementation, would use a length prefix per packet
        for packet in packets {
            combined.append(PacketParser.encode(packet))
        }
        
        return combined
    }
    
    /// Split a coalesced datagram back into individual packets.
    static func split(_ data: Data) throws -> [BlazePacket] {
        var packets: [BlazePacket] = []
        var offset = 0
        
        while offset < data.count {
            // Try to decode a packet starting at offset
            let remaining = data.subdata(in: offset..<data.count)
            
            guard remaining.count >= PacketParser.headerSize else {
                throw PacketParserError.bufferTooSmall
            }
            
            // Read header to get total packet size
            let headerSize = PacketParser.headerSize
            // Read payloadLength manually to avoid alignment issues (offset 14-15 in header)
            let payloadLengthOffset = headerSize - 2
            let payloadLength = UInt16(bigEndian: UInt16(remaining[payloadLengthOffset]) << 8 | UInt16(remaining[payloadLengthOffset + 1]))
            
            let totalSize = headerSize + Int(payloadLength)
            
            guard offset + totalSize <= data.count else {
                throw PacketParserError.truncated
            }
            
            let packetData = data.subdata(in: offset..<(offset + totalSize))
            let packet = try PacketParser.decode(packetData)
            packets.append(packet)
            
            offset += totalSize
        }
        
        return packets
    }
}

