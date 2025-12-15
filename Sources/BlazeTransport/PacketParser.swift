/// Internal packet parsing and serialization.
/// Handles encoding/decoding of BlazePacket structures with big-endian byte order.
import Foundation

/// Errors that can occur during packet parsing.
public enum PacketParserError: Error {
    /// Packet data is truncated (incomplete).
    case truncated
    /// Payload length doesn't match header.
    case invalidPayloadLength
    /// Buffer is too small to contain a valid header.
    case bufferTooSmall
}

/// Parser for BlazePacket structures.
/// Serializes packets to/from Data with big-endian encoding for multi-byte integers.
public struct PacketParser {
    /// Size of packet header in bytes: 1 (version) + 1 (flags) + 4 (connectionID) + 4 (packetNumber) + 4 (streamID) + 2 (payloadLength) = 16 bytes
    public static let headerSize = 16

    /// Encode a BlazePacket into Data.
    /// - Parameter packet: The packet to encode.
    /// - Returns: Serialized packet data with big-endian integers.
    public static func encode(_ packet: BlazePacket) -> Data {
        var data = Data(capacity: headerSize + packet.payload.count)
        
        // Write header fields in big-endian
        data.append(packet.header.version)
        data.append(packet.header.flags)
        data.append(contentsOf: withUnsafeBytes(of: packet.header.connectionID.bigEndian) { Data($0) })
        data.append(contentsOf: withUnsafeBytes(of: packet.header.packetNumber.bigEndian) { Data($0) })
        data.append(contentsOf: withUnsafeBytes(of: packet.header.streamID.bigEndian) { Data($0) })
        data.append(contentsOf: withUnsafeBytes(of: packet.header.payloadLength.bigEndian) { Data($0) })
        
        // Append payload
        data.append(packet.payload)
        
        return data
    }

    /// Decode Data into a BlazePacket.
    /// - Parameter data: The serialized packet data.
    /// - Returns: The decoded packet.
    /// - Throws: `PacketParserError` if the data is invalid or truncated.
    public static func decode(_ data: Data) throws -> BlazePacket {
        guard data.count >= headerSize else {
            throw PacketParserError.bufferTooSmall
        }

        var offset = 0
        
        let version = data[offset]
        offset += 1
        
        let flags = data[offset]
        offset += 1
        
        let connectionID = UInt32(bigEndian: data.withUnsafeBytes { $0.load(fromByteOffset: offset, as: UInt32.self) })
        offset += 4
        
        let packetNumber = UInt32(bigEndian: data.withUnsafeBytes { $0.load(fromByteOffset: offset, as: UInt32.self) })
        offset += 4
        
        let streamID = UInt32(bigEndian: data.withUnsafeBytes { $0.load(fromByteOffset: offset, as: UInt32.self) })
        offset += 4
        
        let payloadLength = UInt16(bigEndian: data.withUnsafeBytes { $0.load(fromByteOffset: offset, as: UInt16.self) })
        offset += 2

        guard data.count >= headerSize + Int(payloadLength) else {
            throw PacketParserError.truncated
        }

        let payload = data.subdata(in: offset..<(offset + Int(payloadLength)))
        
        let header = BlazePacketHeader(
            version: version,
            flags: flags,
            connectionID: connectionID,
            packetNumber: packetNumber,
            streamID: streamID,
            payloadLength: payloadLength
        )

        guard payload.count == Int(payloadLength) else {
            throw PacketParserError.invalidPayloadLength
        }

        return BlazePacket(header: header, payload: payload)
    }
}

