import Testing
@testable import BlazeTransport

/// Tests for connection-level state machine.
@Test("Connection FSM: idle + appOpenRequested → synSent")
func testConnectionFSMIdleToSynSent() async throws {
    var machine = makeConnectionStateMachine()
    // Note: StateMachine API may vary - adjust based on actual BlazeFSM implementation
    let effects = machine.process(.appOpenRequested)
    #expect(effects.count > 0)
    #expect(effects.contains { if case .sendPacket = $0 { return true }; return false })
}

@Test("Connection FSM: synSent + timeout → closed")
func testConnectionFSMTimeout() async throws {
    var machine = makeConnectionStateMachine()
    machine.process(.appOpenRequested) // Move to synSent
    
    let effects = machine.process(.timeout("handshake"))
    #expect(effects.contains { if case .markClosed = $0 { return true }; return false })
}

@Test("Connection FSM: handshake + handshakeSucceeded → active")
func testConnectionFSMHandshakeSuccess() async throws {
    var machine = makeConnectionStateMachine()
    machine.process(.appOpenRequested) // idle → synSent
    machine.process(.packetReceived) // synSent → handshake
    
    let effects = machine.process(.handshakeSucceeded)
    #expect(effects.contains { if case .markActive = $0 { return true }; return false })
}

@Test("Connection FSM: handshake + handshakeFailed → closed")
func testConnectionFSMHandshakeFailure() async throws {
    var machine = makeConnectionStateMachine()
    machine.process(.appOpenRequested) // idle → synSent
    machine.process(.packetReceived) // synSent → handshake
    
    let effects = machine.process(.handshakeFailed)
    #expect(effects.contains { if case .markClosed = $0 { return true }; return false })
}

