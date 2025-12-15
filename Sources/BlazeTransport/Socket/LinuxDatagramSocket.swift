#if canImport(Glibc)
import Foundation
import Glibc

/// Linux (Glibc) UDP socket implementation using POSIX BSD sockets.
final class LinuxDatagramSocket: DatagramSocket {
    private var socketFD: Int32 = -1
    private var isBound = false
    private var boundPort: UInt16?
    
    init() throws {
        socketFD = Glibc.socket(AF_INET, Int32(SOCK_DGRAM.rawValue), Int32(IPPROTO_UDP))
        guard socketFD >= 0 else {
            throw BlazeTransportError.underlying(NSError(domain: "UDPSocket", code: Int(errno), userInfo: nil))
        }
        
        // Set socket options
        var reuseAddr: Int32 = 1
        Glibc.setsockopt(socketFD, SOL_SOCKET, SO_REUSEADDR, &reuseAddr, socklen_t(MemoryLayout<Int32>.size))
        
        // Set non-blocking mode using fcntl
        let flags = Glibc.fcntl(socketFD, F_GETFL, 0)
        guard flags >= 0 else {
            Glibc.close(socketFD)
            throw BlazeTransportError.underlying(NSError(domain: "UDPSocket", code: Int(errno), userInfo: nil))
        }
        let setFlagsResult = Glibc.fcntl(socketFD, F_SETFL, flags | O_NONBLOCK)
        guard setFlagsResult >= 0 else {
            Glibc.close(socketFD)
            throw BlazeTransportError.underlying(NSError(domain: "UDPSocket", code: Int(errno), userInfo: nil))
        }
    }
    
    func bind(host: String, port: UInt16) throws {
        guard !isBound else { return }
        
        var addr = sockaddr_in()
        addr.sin_family = sa_family_t(AF_INET)
        addr.sin_port = port.bigEndian
        
        if host == "0.0.0.0" || host == "127.0.0.1" || host == "localhost" {
            addr.sin_addr.s_addr = in_addr_t(INADDR_ANY)
        } else {
            var hostent = Glibc.gethostbyname(host)
            guard hostent != nil else {
                throw BlazeTransportError.underlying(NSError(domain: "UDPSocket", code: Int(errno), userInfo: nil))
            }
            guard let addrList = hostent!.pointee.h_addr_list, let firstAddr = addrList[0] else {
                throw BlazeTransportError.underlying(NSError(domain: "UDPSocket", code: Int(errno), userInfo: nil))
            }
            addr.sin_addr = firstAddr.withMemoryRebound(to: in_addr.self, capacity: 1) { $0.pointee }
        }
        
        let result = withUnsafePointer(to: &addr) { ptr in
            ptr.withMemoryRebound(to: sockaddr.self, capacity: 1) { sockaddrPtr in
                Glibc.bind(socketFD, sockaddrPtr, socklen_t(MemoryLayout<sockaddr_in>.size))
            }
        }
        
        guard result == 0 else {
            throw BlazeTransportError.underlying(NSError(domain: "UDPSocket", code: Int(errno), userInfo: nil))
        }
        
        // Get actual bound port (for port 0 = ephemeral)
        var boundAddr = sockaddr_in()
        var addrLen = socklen_t(MemoryLayout<sockaddr_in>.size)
        let getsocknameResult = withUnsafeMutablePointer(to: &boundAddr) { ptr in
            ptr.withMemoryRebound(to: sockaddr.self, capacity: 1) { sockaddrPtr in
                Glibc.getsockname(socketFD, sockaddrPtr, &addrLen)
            }
        }
        
        if getsocknameResult == 0 {
            boundPort = UInt16(bigEndian: boundAddr.sin_port)
        } else {
            boundPort = port
        }
        
        isBound = true
    }
    
    func setReceiveBufferSize(_ size: Int) throws {
        guard socketFD >= 0 else {
            throw BlazeTransportError.connectionClosed
        }
        
        var bufferSize = Int32(size)
        let result = Glibc.setsockopt(socketFD, SOL_SOCKET, SO_RCVBUF, &bufferSize, socklen_t(MemoryLayout<Int32>.size))
        
        guard result == 0 else {
            throw BlazeTransportError.underlying(NSError(domain: "UDPSocket", code: Int(errno), userInfo: nil))
        }
    }
    
    func getBoundPort() -> UInt16? {
        return boundPort
    }
    
    func send(to host: String, port: UInt16, data: Data) throws {
        guard socketFD >= 0 else {
            throw BlazeTransportError.connectionClosed
        }
        
        var addr = sockaddr_in()
        addr.sin_family = sa_family_t(AF_INET)
        addr.sin_port = port.bigEndian
        
        if host == "127.0.0.1" || host == "localhost" {
            addr.sin_addr.s_addr = in_addr_t(0x7F000001) // 127.0.0.1
        } else {
            var hostent = Glibc.gethostbyname(host)
            guard hostent != nil else {
                throw BlazeTransportError.underlying(NSError(domain: "UDPSocket", code: Int(errno), userInfo: nil))
            }
            guard let addrList = hostent!.pointee.h_addr_list, let firstAddr = addrList[0] else {
                throw BlazeTransportError.underlying(NSError(domain: "UDPSocket", code: Int(errno), userInfo: nil))
            }
            addr.sin_addr = firstAddr.withMemoryRebound(to: in_addr.self, capacity: 1) { $0.pointee }
        }
        
        let result = data.withUnsafeBytes { bytes in
            withUnsafePointer(to: &addr) { ptr in
                ptr.withMemoryRebound(to: sockaddr.self, capacity: 1) { sockaddrPtr in
                    Glibc.sendto(socketFD, bytes.baseAddress, bytes.count, 0, sockaddrPtr, socklen_t(MemoryLayout<sockaddr_in>.size))
                }
            }
        }
        
        guard result >= 0 else {
            throw BlazeTransportError.underlying(NSError(domain: "UDPSocket", code: Int(errno), userInfo: nil))
        }
    }
    
    func receive(maxBytes: Int) throws -> (Data, String, UInt16) {
        guard socketFD >= 0 else {
            throw BlazeTransportError.connectionClosed
        }
        
        var buffer = Data(count: maxBytes)
        var addr = sockaddr_in()
        var addrLen: socklen_t = socklen_t(MemoryLayout<sockaddr_in>.size)
        
        let result = buffer.withUnsafeMutableBytes { bytes in
            withUnsafeMutablePointer(to: &addr) { ptr in
                ptr.withMemoryRebound(to: sockaddr.self, capacity: 1) { sockaddrPtr in
                    Glibc.recvfrom(socketFD, bytes.baseAddress, maxBytes, 0, sockaddrPtr, &addrLen)
                }
            }
        }
        
        guard result >= 0 else {
            throw BlazeTransportError.underlying(NSError(domain: "UDPSocket", code: Int(errno), userInfo: nil))
        }
        
        buffer = buffer.prefix(result)
        
        var sinAddr = addr.sin_addr
        let hostCString = Glibc.inet_ntoa(sinAddr)
        let host = hostCString != nil ? String(cString: hostCString!) : "0.0.0.0"
        let port = UInt16(bigEndian: addr.sin_port)
        
        return (buffer, host, port)
    }
    
    func close() throws {
        guard socketFD >= 0 else { return }
        
        // Graceful shutdown: disable sends first
        Glibc.shutdown(socketFD, Int32(SHUT_WR))
        Glibc.close(socketFD)
        socketFD = -1
        isBound = false
        boundPort = nil
    }
    
    deinit {
        if socketFD >= 0 {
            Glibc.close(socketFD)
        }
    }
}

#endif

