import Foundation

#if canImport(Darwin)
import Darwin
#elseif canImport(Glibc)
import Glibc
#endif

/// Protocol abstraction for UDP datagram sockets.
/// Allows for testable implementations (real UDP vs mock).
protocol DatagramSocket {
    func bind(host: String, port: UInt16) throws
    func send(to host: String, port: UInt16, data: Data) throws
    func receive(maxBytes: Int) throws -> (Data, String, UInt16)
    func close() throws
    func setReceiveBufferSize(_ size: Int) throws
    func getBoundPort() -> UInt16?
}

/// Real UDP socket implementation using POSIX BSD sockets.
final class UDPSocket: DatagramSocket {
    private var socketFD: Int32 = -1
    private var isBound = false
    
    init() throws {
        #if canImport(Darwin)
        socketFD = Darwin.socket(AF_INET, SOCK_DGRAM, 0)
        #elseif canImport(Glibc)
        socketFD = Glibc.socket(AF_INET, Int32(SOCK_DGRAM.rawValue), 0)
        #endif
        guard socketFD >= 0 else {
            throw BlazeTransportError.underlying(NSError(domain: "UDPSocket", code: Int(errno), userInfo: nil))
        }
        
        // Set socket options
        var reuseAddr: Int32 = 1
        #if canImport(Darwin)
        Darwin.setsockopt(socketFD, SOL_SOCKET, SO_REUSEADDR, &reuseAddr, socklen_t(MemoryLayout<Int32>.size))
        #elseif canImport(Glibc)
        Glibc.setsockopt(socketFD, SOL_SOCKET, SO_REUSEADDR, &reuseAddr, socklen_t(MemoryLayout<Int32>.size))
        #endif
    }
    
    private var boundPort: UInt16?
    
    func bind(host: String, port: UInt16) throws {
        guard !isBound else { return }
        
        var addr = sockaddr_in()
        addr.sin_family = sa_family_t(AF_INET)
        addr.sin_port = port.bigEndian
        
        if host == "0.0.0.0" || host == "127.0.0.1" || host == "localhost" {
            addr.sin_addr.s_addr = in_addr_t(INADDR_ANY)
        } else {
            #if canImport(Darwin)
            var hostent = Darwin.gethostbyname(host)
            #elseif canImport(Glibc)
            var hostent = Glibc.gethostbyname(host)
            #endif
            guard hostent != nil else {
                throw BlazeTransportError.underlying(NSError(domain: "UDPSocket", code: Int(errno), userInfo: nil))
            }
            guard let addrList = hostent!.pointee.h_addr_list, let firstAddr = addrList[0] else {
                throw BlazeTransportError.underlying(NSError(domain: "UDPSocket", code: Int(errno), userInfo: nil))
            }
            #if canImport(Darwin)
            addr.sin_addr = firstAddr.pointee
            #elseif canImport(Glibc)
            addr.sin_addr = firstAddr.withMemoryRebound(to: in_addr.self, capacity: 1) { $0.pointee }
            #endif
        }
        
        let result = withUnsafePointer(to: &addr) { ptr in
            ptr.withMemoryRebound(to: sockaddr.self, capacity: 1) { sockaddrPtr in
                #if canImport(Darwin)
                Darwin.bind(socketFD, sockaddrPtr, socklen_t(MemoryLayout<sockaddr_in>.size))
                #elseif canImport(Glibc)
                Glibc.bind(socketFD, sockaddrPtr, socklen_t(MemoryLayout<sockaddr_in>.size))
                #endif
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
                #if canImport(Darwin)
                Darwin.getsockname(socketFD, sockaddrPtr, &addrLen)
                #elseif canImport(Glibc)
                Glibc.getsockname(socketFD, sockaddrPtr, &addrLen)
                #endif
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
        #if canImport(Darwin)
        let result = Darwin.setsockopt(socketFD, SOL_SOCKET, SO_RCVBUF, &bufferSize, socklen_t(MemoryLayout<Int32>.size))
        #elseif canImport(Glibc)
        let result = Glibc.setsockopt(socketFD, SOL_SOCKET, SO_RCVBUF, &bufferSize, socklen_t(MemoryLayout<Int32>.size))
        #else
        let result = -1
        #endif
        
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
            #if canImport(Darwin)
            var hostent = Darwin.gethostbyname(host)
            #elseif canImport(Glibc)
            var hostent = Glibc.gethostbyname(host)
            #endif
            guard hostent != nil else {
                throw BlazeTransportError.underlying(NSError(domain: "UDPSocket", code: Int(errno), userInfo: nil))
            }
            guard let addrList = hostent!.pointee.h_addr_list, let firstAddr = addrList[0] else {
                throw BlazeTransportError.underlying(NSError(domain: "UDPSocket", code: Int(errno), userInfo: nil))
            }
            #if canImport(Darwin)
            addr.sin_addr = firstAddr.pointee
            #elseif canImport(Glibc)
            addr.sin_addr = firstAddr.withMemoryRebound(to: in_addr.self, capacity: 1) { $0.pointee }
            #endif
        }
        
        let result = data.withUnsafeBytes { bytes in
            withUnsafePointer(to: &addr) { ptr in
                ptr.withMemoryRebound(to: sockaddr.self, capacity: 1) { sockaddrPtr in
                    #if canImport(Darwin)
                    Darwin.sendto(socketFD, bytes.baseAddress, bytes.count, 0, sockaddrPtr, socklen_t(MemoryLayout<sockaddr_in>.size))
                    #elseif canImport(Glibc)
                    Glibc.sendto(socketFD, bytes.baseAddress, bytes.count, 0, sockaddrPtr, socklen_t(MemoryLayout<sockaddr_in>.size))
                    #endif
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
                    #if canImport(Darwin)
                    Darwin.recvfrom(socketFD, bytes.baseAddress, maxBytes, 0, sockaddrPtr, &addrLen)
                    #elseif canImport(Glibc)
                    Glibc.recvfrom(socketFD, bytes.baseAddress, maxBytes, 0, sockaddrPtr, &addrLen)
                    #endif
                }
            }
        }
        
        guard result >= 0 else {
            throw BlazeTransportError.underlying(NSError(domain: "UDPSocket", code: Int(errno), userInfo: nil))
        }
        
        buffer = buffer.prefix(result)
        
        #if canImport(Darwin)
        let host = String(cString: Darwin.inet_ntoa(addr.sin_addr))
        #elseif canImport(Glibc)
        var sinAddr = addr.sin_addr
        let hostCString = Glibc.inet_ntoa(sinAddr)
        let host = hostCString != nil ? String(cString: hostCString!) : "0.0.0.0"
        #endif
        let port = UInt16(bigEndian: addr.sin_port)
        
        return (buffer, host, port)
    }
    
    func close() throws {
        guard socketFD >= 0 else { return }
        
        // Graceful shutdown: disable sends first
        #if canImport(Darwin)
        Darwin.shutdown(socketFD, SHUT_WR)
        Darwin.close(socketFD)
        #elseif canImport(Glibc)
        Glibc.shutdown(socketFD, SHUT_WR)
        Glibc.close(socketFD)
        #endif
        socketFD = -1
        isBound = false
        boundPort = nil
    }
    
    deinit {
        if socketFD >= 0 {
            #if canImport(Darwin)
            Darwin.close(socketFD)
            #elseif canImport(Glibc)
            Glibc.close(socketFD)
            #endif
        }
    }
}

