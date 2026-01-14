import XCTest
@testable import BlazeTransport

/// Tests for connection-level state machine.
final class ConnectionFSMTests: XCTestCase {
    
    func testConnectionFSMIdleToSynSent() async throws {
        var machine = makeConnectionStateMachine()
        // Note: StateMachine API may vary - adjust based on actual BlazeFSM implementation
        let effects = machine.process(.appOpenRequested)
        XCTAssertTrue(effects.count > 0)
        XCTAssertTrue(effects.contains { if case .sendPacket = $0 { return true }; return false })
    }
    
    func testConnectionFSMTimeout() async throws {
        var machine = makeConnectionStateMachine()
        _ = machine.process(.appOpenRequested) // Move to synSent
        
        let effects = machine.process(.timeout("handshake"))
        XCTAssertTrue(effects.contains { if case .markClosed = $0 { return true }; return false })
    }
    
    func testConnectionFSMHandshakeSuccess() async throws {
        var machine = makeConnectionStateMachine()
        _ = machine.process(.appOpenRequested) // idle → synSent
        _ = machine.process(.packetReceived) // synSent → handshake
        
        let effects = machine.process(.handshakeSucceeded)
        XCTAssertTrue(effects.contains { if case .markActive = $0 { return true }; return false })
    }
    
    func testConnectionFSMHandshakeFailure() async throws {
        var machine = makeConnectionStateMachine()
        _ = machine.process(.appOpenRequested) // idle → synSent
        _ = machine.process(.packetReceived) // synSent → handshake
        
        let effects = machine.process(.handshakeFailed)
        XCTAssertTrue(effects.contains { if case .markClosed = $0 { return true }; return false })
    }
}
