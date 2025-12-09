/// Internal frame type definitions for stream-level framing.
import Foundation

/// Types of frames that can be sent over a stream.
enum BlazeFrameType: UInt8 {
    case data = 0
    case ack = 1
    case ping = 2
    case pong = 3
    case reset = 4
    case handshake = 5
}

/// Frame structure for stream-level data transmission.
struct BlazeFrame {
    var type: BlazeFrameType
    var streamID: UInt32
    var payload: Data
}

