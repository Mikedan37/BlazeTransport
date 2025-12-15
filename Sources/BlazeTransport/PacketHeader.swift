/// Internal packet structures for the BlazeTransport protocol.
import Foundation

/// Packet header containing metadata for a BlazePacket.
public struct BlazePacketHeader: Sendable {
    public var version: UInt8
    public var flags: UInt8
    public var connectionID: UInt32
    public var packetNumber: UInt32
    public var streamID: UInt32
    public var payloadLength: UInt16
    
    public init(version: UInt8, flags: UInt8, connectionID: UInt32, packetNumber: UInt32, streamID: UInt32, payloadLength: UInt16) {
        self.version = version
        self.flags = flags
        self.connectionID = connectionID
        self.packetNumber = packetNumber
        self.streamID = streamID
        self.payloadLength = payloadLength
    }
}

/// Complete packet structure with header and payload.
public struct BlazePacket: Sendable {
    public var header: BlazePacketHeader
    public var payload: Data
    
    public init(header: BlazePacketHeader, payload: Data) {
        self.header = header
        self.payload = payload
    }
}

