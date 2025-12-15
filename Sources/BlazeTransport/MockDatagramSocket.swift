import Foundation

/// Mock datagram socket for testing and benchmarks.
/// Provides in-memory loopback without real network I/O.
final class MockDatagramSocket: DatagramSocket {
    private var boundAddress: (host: String, port: UInt16)?
    private var receiveQueue: [(Data, String, UInt16)] = []
    private var isClosed = false
    private let lock = NSLock()
    
    // Shared registry for loopback communication
    private static var sockets: [String: MockDatagramSocket] = [:]
    private static let registryLock = NSLock()
    
    private func addressKey(host: String, port: UInt16) -> String {
        return "\(host):\(port)"
    }
    
    func bind(host: String, port: UInt16) throws {
        lock.lock()
        defer { lock.unlock() }
        
        guard !isClosed else {
            throw BlazeTransportError.connectionClosed
        }
        
        let key = addressKey(host, port)
        MockDatagramSocket.registryLock.lock()
        defer { MockDatagramSocket.registryLock.unlock() }
        
        guard MockDatagramSocket.sockets[key] == nil else {
            throw BlazeTransportError.underlying(NSError(domain: "MockSocket", code: EADDRINUSE, userInfo: nil))
        }
        
        boundAddress = (host, port)
        MockDatagramSocket.sockets[key] = self
    }
    
    func send(to host: String, port: UInt16, data: Data) throws {
        lock.lock()
        defer { lock.unlock() }
        
        guard !isClosed else {
            throw BlazeTransportError.connectionClosed
        }
        
        let key = addressKey(host, port)
        MockDatagramSocket.registryLock.lock()
        defer { MockDatagramSocket.registryLock.unlock() }
        
        if let targetSocket = MockDatagramSocket.sockets[key] {
            targetSocket.lock.lock()
            defer { targetSocket.lock.unlock() }
            targetSocket.receiveQueue.append((data, host, port))
        }
    }
    
    func receive(maxBytes: Int) throws -> (Data, String, UInt16) {
        lock.lock()
        defer { lock.unlock() }
        
        guard !isClosed else {
            throw BlazeTransportError.connectionClosed
        }
        
        // Wait for data (simplified - in real implementation would use async/await)
        while receiveQueue.isEmpty {
            lock.unlock()
            Thread.sleep(forTimeInterval: 0.001) // 1ms
            lock.lock()
            
            if isClosed {
                throw BlazeTransportError.connectionClosed
            }
        }
        
        return receiveQueue.removeFirst()
    }
    
    func close() throws {
        lock.lock()
        defer { lock.unlock() }
        
        guard !isClosed else { return }
        isClosed = true
        
        if let bound = boundAddress {
            let key = addressKey(host: bound.host, port: bound.port)
            MockDatagramSocket.registryLock.lock()
            defer { MockDatagramSocket.registryLock.unlock() }
            MockDatagramSocket.sockets.removeValue(forKey: key)
        }
    }
    
    func setReceiveBufferSize(_ size: Int) throws {
        // No-op for mock socket
    }
    
    func getBoundPort() -> UInt16? {
        lock.lock()
        defer { lock.unlock() }
        return boundAddress?.port
    }
}

