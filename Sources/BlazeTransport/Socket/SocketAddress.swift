/// Platform-neutral socket address representation.
public struct SocketAddress {
    public let ip: String
    public let port: UInt16
    
    public init(ip: String, port: UInt16) {
        self.ip = ip
        self.port = port
    }
}

