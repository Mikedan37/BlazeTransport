import Testing
@testable import BlazeTransport

/// Tests for stream-level state machine.
@Test("Stream FSM: idle + appSend → open")
func testStreamFSMIdleToOpen() async throws {
    var machine = makeStreamStateMachine()
    
    let effects = machine.process(.appSend)
    #expect(effects.contains { if case .emitFrame = $0 { return true }; return false })
}

@Test("Stream FSM: open + frameReceived → open (stays open)")
func testStreamFSMOpenReceivesFrame() async throws {
    var machine = makeStreamStateMachine()
    machine.process(.appSend) // idle → open
    
    let effects = machine.process(.frameReceived)
    #expect(effects.contains { if case .deliverToApp = $0 { return true }; return false })
}

@Test("Stream FSM: open + appClose → halfClosedLocal")
func testStreamFSMAppClose() async throws {
    var machine = makeStreamStateMachine()
    machine.process(.appSend) // idle → open
    
    let effects = machine.process(.appClose)
    #expect(effects.contains { if case .emitFrame = $0 { return true }; return false })
}

@Test("Stream FSM: open + resetReceived → closed")
func testStreamFSMReset() async throws {
    var machine = makeStreamStateMachine()
    machine.process(.appSend) // idle → open
    
    let effects = machine.process(.resetReceived)
    #expect(effects.contains { if case .markClosed = $0 { return true }; return false })
}

