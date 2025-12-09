/// Low-level packet engine for UDP socket abstraction.
/// Handles sending/receiving packets over the network using real UDP sockets.
import Foundation

/// Actor that manages the underlying UDP socket and packet I/O.
actor PacketEngine {
    private var inboundHandler: (@Sendable (BlazePacket) async -> Void)?
    private var isRunning = false
    private let host: String
    private let port: UInt16
    private var socket: DatagramSocket?
    private var receiveTask: Task<Void, Never>?
    private let useMockSocket: Bool
    
    init(host: String, port: UInt16, useMockSocket: Bool = false) {
        self.host = host
        self.port = port
        self.useMockSocket = useMockSocket
    }
    
    init(host: String, port: UInt16, socket: DatagramSocket) {
        self.host = host
        self.port = port
        self.socket = socket
        self.useMockSocket = false
    }

    func start() async throws {
        guard !isRunning else { return }
        
        // Create socket if not provided
        if socket == nil {
            if useMockSocket {
                socket = MockDatagramSocket()
            } else {
                socket = try UDPSocket()
            }
        }
        
        guard let socket = socket else {
            throw BlazeTransportError.connectionClosed
        }
        
        // Bind socket
        try socket.bind(host: host, port: port)
        
        isRunning = true
        
        // Start receive loop
        receiveTask = Task.detached { [weak self] in
            guard let self = self else { return }
            await self.receiveLoop()
        }
    }
    
    private func receiveLoop() async {
        guard let socket = socket else { return }
        
        while isRunning {
            do {
                let (data, _, _) = try socket.receive(maxBytes: 65535)
                
                // Parse packet
                do {
                    let packet = try PacketParser.decode(data)
                    await inboundHandler?(packet)
                } catch {
                    // Invalid packet, ignore
                    continue
                }
            } catch {
                if isRunning {
                    // Socket error, stop receiving
                    break
                }
            }
        }
    }

    func send(_ packet: BlazePacket) async throws {
        guard isRunning, let socket = socket else {
            throw BlazeTransportError.connectionClosed
        }
        
        // Serialize packet
        let data = PacketParser.encode(packet)
        
        // Send via UDP
        try socket.send(to: host, port: port, data: data)
    }

    func setInboundHandler(_ handler: @Sendable @escaping (BlazePacket) async -> Void) {
        self.inboundHandler = handler
    }
    
    func close() async {
        guard isRunning else { return }
        isRunning = false
        
        receiveTask?.cancel()
        receiveTask = nil
        
        try? socket?.close()
        socket = nil
    }
}

