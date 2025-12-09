/// Internal packet structures for the BlazeTransport protocol.
import Foundation

/// Packet header containing metadata for a BlazePacket.
struct BlazePacketHeader {
    var version: UInt8
    var flags: UInt8
    var connectionID: UInt32
    var packetNumber: UInt32
    var streamID: UInt32
    var payloadLength: UInt16
}

/// Complete packet structure with header and payload.
struct BlazePacket {
    var header: BlazePacketHeader
    var payload: Data
}

