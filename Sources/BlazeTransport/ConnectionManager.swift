/// Main connection manager orchestrating all transport components.
/// Coordinates PacketEngine, StreamManager, ReliabilityEngine, CongestionController, and FSMs.
import Foundation

/// Central actor managing connection state, streams, and packet routing.
actor ConnectionManager {
    let packetEngine: PacketEngine
    var connectionMachine: ConnectionStateMachine
    let streamManager: StreamManager
    let streamBuffer: StreamBuffer
    var reliability: ReliabilityEngine
    var congestion: CongestionController
    var migration: ConnectionMigration
    var securityManager: SecurityManager
    var streamPriority: StreamPriorityQueue

    private let host: String
    private let port: UInt16
    private let security: BlazeSecurityConfig

    private var isActive = false
    private var isClosed = false
    private var bytesSent: Int = 0
    private var bytesReceived: Int = 0
    private var streamReceivers: [UInt32: AsyncStream<Data>] = [:]
    private var pendingPackets: [BlazePacket] = []  // For coalescing

    private var timers: [String: Task<Void, Never>] = [:]
    private var packetsSent: Int = 0
    private var packetsAcked: Int = 0
    private var packetsLost: Int = 0
    private var inFlightBytes: Int = 0
    private var sendQueue: [(Data, UInt32)] = []
    
    init(host: String, port: UInt16, security: BlazeSecurityConfig, useMockSocket: Bool = false) {
        self.host = host
        self.port = port
        self.security = security
        self.packetEngine = PacketEngine(host: host, port: port, useMockSocket: useMockSocket)
        self.connectionMachine = makeConnectionStateMachine()
        self.streamManager = StreamManager()
        self.streamBuffer = StreamBuffer()
        self.reliability = ReliabilityEngine()
        self.congestion = CongestionController()
        self.migration = ConnectionMigration(host: host, port: port)
        self.securityManager = SecurityManager()
        self.streamPriority = StreamPriorityQueue()
    }

    func start() async throws {
        // Set up packet handler
        await packetEngine.setInboundHandler { [weak self] packet in
            guard let self = self else { return }
            await self.handleInboundPacket(packet)
        }

        // Start packet engine
        try await packetEngine.start()

        // Trigger connection handshake
        let effects = connectionMachine.process(.appOpenRequested)
        await applyEffects(effects, packet: nil)
    }

    func openStream() async throws -> DefaultBlazeStream {
        guard !isClosed else {
            throw BlazeTransportError.connectionClosed
        }

        let streamID = await streamManager.openStream()
        let receiver = await streamBuffer.register(streamID: streamID)
        streamReceivers[streamID] = receiver
        return DefaultBlazeStream(streamID: streamID, connectionManager: self)
    }

    func send(data: Data, on streamID: UInt32) async throws {
        guard !isClosed else {
            throw BlazeTransportError.connectionClosed
        }

        // Get effects from stream manager
        let effects = await streamManager.handleAppSend(on: streamID, data: data)

        // Process effects (emit frames)
        for effect in effects {
            switch effect {
            case .emitFrame(let frameData):
                // Create frame with type prefix
                var framePayload = Data()
                framePayload.append(BlazeFrameType.data.rawValue)
                framePayload.append(frameData)
                
                // Check congestion window and pacing
                let canSend = congestion.canSend(bytes: framePayload.count, now: Date())
                guard canSend else {
                    // Queue for later
                    sendQueue.append((frameData, streamID))
                    continue
                }
                
                // Create packet with frame data
                let packetNumber = reliability.nextPacketNumber()
                let packet = BlazePacket(
                    header: BlazePacketHeader(
                        version: 1,
                        flags: 0,
                        connectionID: 0,
                        packetNumber: packetNumber,
                        streamID: streamID,
                        payloadLength: UInt16(framePayload.count)
                    ),
                    payload: framePayload
                )

                reliability.notePacketSent(packetNumber)
                packetsSent += 1
                inFlightBytes += framePayload.count
                congestion.markInFlight(bytes: framePayload.count)
                
                // Add to pending packets for coalescing
                pendingPackets.append(packet)
                
                // Flush pending packets if batch is ready or MTU would be exceeded
                await flushPendingPackets()
                
                bytesSent += framePayload.count
                
                // Process queued packets if window allows
                await processSendQueue()

            case .deliverToApp, .markClosed:
                // Handled elsewhere
                break
            }
        }
    }
    
    private func processSendQueue() async {
        while !sendQueue.isEmpty && inFlightBytes < congestion.congestionWindowBytes {
            let (frameData, streamID) = sendQueue.removeFirst()
            
            if inFlightBytes + frameData.count > congestion.congestionWindowBytes {
                sendQueue.insert((frameData, streamID), at: 0)
                break
            }
            
            // Create frame with type prefix
            var framePayload = Data()
            framePayload.append(BlazeFrameType.data.rawValue)
            framePayload.append(frameData)
            
            let packetNumber = reliability.nextPacketNumber()
            let packet = BlazePacket(
                header: BlazePacketHeader(
                    version: 1,
                    flags: 0,
                    connectionID: 0,
                    packetNumber: packetNumber,
                    streamID: streamID,
                    payloadLength: UInt16(framePayload.count)
                ),
                payload: framePayload
            )
            
            reliability.notePacketSent(packetNumber)
            packetsSent += 1
            inFlightBytes += framePayload.count
            
            do {
                try await packetEngine.send(packet)
                bytesSent += framePayload.count
            } catch {
                // Handle error
            }
        }
    }

    func receive(on streamID: UInt32) async throws -> Data {
        guard !isClosed else {
            throw BlazeTransportError.connectionClosed
        }

        guard let receiver = streamReceivers[streamID] else {
            throw BlazeTransportError.connectionClosed
        }

        // Wait for next data from stream buffer
        for await data in receiver {
            return data
        }

        // Stream was closed
        throw BlazeTransportError.connectionClosed
    }

    func close() async throws {
        guard !isClosed else { return }
        isClosed = true

        let effects = connectionMachine.process(.appCloseRequested)
        await applyEffects(effects, packet: nil)
    }

    /// Close a specific stream.
    func closeStream(_ streamID: UInt32) async {
        await streamManager.closeStream(streamID)
        await streamBuffer.close(streamID: streamID)
        streamReceivers.removeValue(forKey: streamID)
    }

    func stats() async -> BlazeTransportStats {
        let rtt = reliability.rttEstimate ?? 0.0
        let congestionWindow = congestion.congestionWindowBytes
        
        // Calculate loss rate over sent packets
        let lossRate = packetsSent > 0 ? Double(packetsLost) / Double(packetsSent) : 0.0

        return BlazeTransportStats(
            roundTripTime: rtt,
            congestionWindowBytes: congestionWindow,
            lossRate: lossRate,
            bytesSent: bytesSent,
            bytesReceived: bytesReceived
        )
    }

    // MARK: - Private Helpers

    private func handleInboundPacket(_ packet: BlazePacket) async {
        bytesReceived += packet.payload.count
        
        // Validate address (connection migration check)
        // Note: In real implementation, would get address from socket
        // For now, assume address is valid
        
        // Feed event to connection state machine (matched by case, not value)
        let effects = connectionMachine.process(.packetReceived)
        await applyEffects(effects, packet: packet)

        // Parse frame type
        guard !packet.payload.isEmpty else { return }
        
        let frameTypeRaw = packet.payload[0]
        guard let frameType = BlazeFrameType(rawValue: frameTypeRaw) else { return }
        
        // Handle ACK frames
        if frameType == .ack {
            // Parse ACK frame with selective ACK ranges
            let ackRanges = parseAckFrame(packet.payload)
            
            // Process each ACK range
            for range in ackRanges {
                for packetNum in range.start...range.end {
                    if !reliability.isAcked(packetNum) {
                        reliability.noteAckReceived(for: packetNum)
                        packetsAcked += 1
                    }
                }
            }
            
            // Update congestion control with RTT
            let bytesAcked = Int(packet.header.payloadLength)
            let rtt = reliability.rttEstimate
            congestion.onAck(bytesAcked: bytesAcked, rtt: rtt)
            inFlightBytes = max(0, inFlightBytes - bytesAcked)
            
            // Check for key rotation
            if securityManager.shouldRotateKey(now: Date()) {
                // TODO: Rotate key (would generate new key from handshake)
            }
            
            // Process send queue now that window may have opened
            await processSendQueue()
            return
        }
        
        // Send ACK for data frames
        if frameType == .data && packet.header.streamID != 0 {
            // Generate ACK frame
            let ackFrame = createAckFrame(for: packet.header.packetNumber)
            let ackPacket = BlazePacket(
                header: BlazePacketHeader(
                    version: 1,
                    flags: 0,
                    connectionID: 0,
                    packetNumber: reliability.nextPacketNumber(),
                    streamID: 0, // ACK frames use streamID 0
                    payloadLength: UInt16(ackFrame.count)
                ),
                payload: ackFrame
            )
            
            do {
                try await packetEngine.send(ackPacket)
            } catch {
                // Ignore ACK send errors
            }
        }

        // Route data frames to stream manager
        if frameType == .data && packet.header.streamID != 0 {
            let streamEffects = await streamManager.handleFrameReceived(
                streamID: packet.header.streamID,
                data: packet.payload.dropFirst(1) // Skip frame type byte
            )

            // Process stream effects
            for effect in streamEffects {
                switch effect {
                case .deliverToApp(let data):
                    // Deliver data to stream buffer
                    await streamBuffer.deliver(streamID: packet.header.streamID, data: data)
                case .emitFrame:
                    // Outbound frame (shouldn't happen on receive path)
                    break
                case .markClosed:
                    await streamManager.closeStream(packet.header.streamID)
                    await streamBuffer.close(streamID: packet.header.streamID)
                    streamReceivers.removeValue(forKey: packet.header.streamID)
                }
            }
        }
    }
    
    private func createAckFrame(for packetNumber: UInt32) -> Data {
        var data = Data()
        data.append(BlazeFrameType.ack.rawValue)
        
        // Get selective ACK ranges
        let ackRanges = reliability.getAckRanges()
        
        // Encode largest ACKed packet number
        withUnsafeBytes(of: packetNumber.bigEndian) { bytes in
            data.append(contentsOf: bytes)
        }
        
        // Encode number of ranges (1 byte)
        data.append(UInt8(min(ackRanges.count, 255)))
        
        // Encode each range (start and end, 4 bytes each)
        for range in ackRanges.prefix(255) {
            withUnsafeBytes(of: range.start.bigEndian) { bytes in
                data.append(contentsOf: bytes)
            }
            withUnsafeBytes(of: range.end.bigEndian) { bytes in
                data.append(contentsOf: bytes)
            }
        }
        
        return data
    }
    
    private func parseAckFrame(_ data: Data) -> [AckRange] {
        guard data.count >= 5 else { return [] }  // frame type + packet number (4 bytes)
        
        var offset = 1  // Skip frame type
        var ranges: [AckRange] = []
        
        // Read largest ACKed packet number
        let largestAcked = data.withUnsafeBytes { bytes in
            bytes.load(fromByteOffset: offset, as: UInt32.self).bigEndian
        }
        offset += 4
        
        // Read number of ranges
        guard data.count > offset else { return [] }
        let rangeCount = Int(data[offset])
        offset += 1
        
        // Read ranges
        for _ in 0..<min(rangeCount, 255) {
            guard data.count >= offset + 8 else { break }  // Need 8 bytes for start + end
            
            let start = data.withUnsafeBytes { bytes in
                bytes.load(fromByteOffset: offset, as: UInt32.self).bigEndian
            }
            offset += 4
            
            let end = data.withUnsafeBytes { bytes in
                bytes.load(fromByteOffset: offset, as: UInt32.self).bigEndian
            }
            offset += 4
            
            ranges.append(AckRange(start: start, end: end))
        }
        
        // If no ranges, create single range for largest ACKed
        if ranges.isEmpty {
            ranges.append(AckRange(start: largestAcked, end: largestAcked))
        }
        
        return ranges
    }
    
    private func flushPendingPackets() async {
        guard !pendingPackets.isEmpty else { return }
        
        // Coalesce packets if multiple pending and MTU permits
        if pendingPackets.count > 1 {
            let coalesced = PacketCoalescer.coalesce(pendingPackets)
            for datagram in coalesced {
                // For now, send packets individually
                // In full implementation, would send coalesced datagram directly
                // This requires PacketEngine to support raw datagram sending
            }
        }
        
        // Send all pending packets
        for packet in pendingPackets {
            do {
                try await packetEngine.send(packet)
            } catch {
                // Handle error - packet will be retransmitted if needed
            }
        }
        
        pendingPackets.removeAll()
    }

    private func applyEffects(_ effects: [ConnectionEffect], packet: BlazePacket? = nil) async {
        for effect in effects {
            switch effect {
            case .sendPacket(let effectPacket):
                // Use packet from effect, or construct from current packet if needed
                let packetToSend = effectPacket.header.packetNumber == 0 && packet != nil
                    ? BlazePacket(
                        header: BlazePacketHeader(
                            version: effectPacket.header.version,
                            flags: effectPacket.header.flags,
                            connectionID: effectPacket.header.connectionID,
                            packetNumber: reliability.nextPacketNumber(),
                            streamID: effectPacket.header.streamID,
                            payloadLength: UInt16(effectPacket.payload.count)
                        ),
                        payload: effectPacket.payload
                    )
                    : effectPacket
                
                do {
                    try await packetEngine.send(packetToSend)
                    reliability.notePacketSent(packetToSend.header.packetNumber)
                } catch {
                    // TODO: Handle send errors
                }

            case .startTimer(let timerID, let interval):
                // Cancel existing timer if any
                timers[timerID]?.cancel()
                
                // Create new timer task
                let timerIDCopy = timerID
                timers[timerID] = Task { [weak self] in
                    try? await Task.sleep(for: .seconds(interval))
                    
                    guard let self = self else { return }
                    await self.handleTimeout(timerID: timerIDCopy)
                }

            case .cancelTimer(let timerID):
                timers[timerID]?.cancel()
                timers.removeValue(forKey: timerID)

            case .markHandshakeStarted:
                // No-op for now
                break

            case .markActive:
                isActive = true

            case .markClosed:
                isClosed = true
            }
        }
    }
    
    private func handleTimeout(timerID: String) async {
        let effects = connectionMachine.process(.timeout(timerID))
        await applyEffects(effects, packet: nil)
        
        // Handle retransmission timeout
        if timerID.hasPrefix("retransmit-") {
            let now = Date()
            let timeout = reliability.rttEstimate.map { $0 * 2 } ?? 1.0
            let timedOut = reliability.timedOutPackets(now: now, timeout: timeout)
            
            for packetNumber in timedOut {
                packetsLost += 1
                congestion.onLoss()
                // TODO: Retransmit packet
            }
        }
    }
}

