import Foundation

/// Platform-neutral protocol for UDP datagram sockets.
/// Allows for testable implementations (real UDP vs mock).
public protocol DatagramSocket {
    func bind(host: String, port: UInt16) throws
    func send(to host: String, port: UInt16, data: Data) throws
    func receive(maxBytes: Int) throws -> (Data, String, UInt16)
    func close() throws
    func setReceiveBufferSize(_ size: Int) throws
    func getBoundPort() -> UInt16?
}

