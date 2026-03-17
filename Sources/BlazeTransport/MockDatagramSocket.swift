import Foundation

/// Shared registry for mock socket communication.
/// Uses nonisolated(unsafe) for test-only code to avoid Swift 6 concurrency issues.
enum MockSocketRegistry {
    nonisolated(unsafe) static var sockets: [String: MockDatagramSocket] = [:]
    
    /// Reset the registry (for test cleanup).
    nonisolated(unsafe) static func reset() {
        sockets.removeAll()
    }
}

/// Mock datagram socket for testing and benchmarks.
/// Provides in-memory loopback without real network I/O.
final class MockDatagramSocket: DatagramSocket {
    private var boundAddress: (host: String, port: UInt16)?
    private var receiveQueue: [(Data, String, UInt16)] = []
    private var isClosed = false
    
    private func addressKey(host: String, port: UInt16) -> String {
        return "\(host):\(port)"
    }
    
    func bind(host: String, port: UInt16) throws {
        guard !isClosed else {
            throw BlazeTransportError.connectionClosed
        }
        
        let key = addressKey(host: host, port: port)
        
        // If already bound to this address, allow rebind (no-op)
        if let bound = boundAddress, bound.host == host && bound.port == port {
            return
        }
        
        // If bound to a different address, remove old binding first
        if let bound = boundAddress {
            let oldKey = addressKey(host: bound.host, port: bound.port)
            MockSocketRegistry.sockets.removeValue(forKey: oldKey)
        }
        
        // Check if address is already in use by another socket
        guard MockSocketRegistry.sockets[key] == nil else {
            throw BlazeTransportError.underlying(NSError(domain: "MockSocket", code: Int(EADDRINUSE), userInfo: nil))
        }
        
        boundAddress = (host, port)
        MockSocketRegistry.sockets[key] = self
    }
    
    func send(to host: String, port: UInt16, data: Data) throws {
        guard !isClosed else {
            throw BlazeTransportError.connectionClosed
        }

        let key = addressKey(host: host, port: port)
        let fromHost = boundAddress?.host ?? "0.0.0.0"
        let fromPort = boundAddress?.port ?? 0
        if let targetSocket = MockSocketRegistry.sockets[key] {
            targetSocket.enqueue(data: data, fromHost: fromHost, fromPort: fromPort)
        }
    }
    
    private func enqueue(data: Data, fromHost: String, fromPort: UInt16) {
        receiveQueue.append((data, fromHost, fromPort))
    }
    
    func receive(maxBytes: Int) throws -> (Data, String, UInt16) {
        guard !isClosed else {
            throw BlazeTransportError.connectionClosed
        }
        
        // Wait for data (simplified - in real implementation would use async/await)
        while receiveQueue.isEmpty {
            Thread.sleep(forTimeInterval: 0.001) // 1ms
            
            if isClosed {
                throw BlazeTransportError.connectionClosed
            }
        }
        
        return receiveQueue.removeFirst()
    }
    
    func close() throws {
        guard !isClosed else { return }
        isClosed = true
        
        if let bound = boundAddress {
            let key = addressKey(host: bound.host, port: bound.port)
            MockSocketRegistry.sockets.removeValue(forKey: key)
        }
    }
    
    func setReceiveBufferSize(_ size: Int) throws {
        // No-op for mock socket
    }
    
    func getBoundPort() -> UInt16? {
        return boundAddress?.port
    }
}

