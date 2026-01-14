import XCTest
@testable import BlazeTransport

/// Tests for stream-level state machine.
final class StreamFSMTests: XCTestCase {
    
    func testStreamFSMIdleToOpen() async throws {
        var machine = makeStreamStateMachine()
        
        let effects = machine.process(.appSend)
        XCTAssertTrue(effects.contains { if case .emitFrame = $0 { return true }; return false })
    }
    
    func testStreamFSMOpenReceivesFrame() async throws {
        var machine = makeStreamStateMachine()
        _ = machine.process(.appSend) // idle → open
        
        let effects = machine.process(.frameReceived)
        XCTAssertTrue(effects.contains { if case .deliverToApp = $0 { return true }; return false })
    }
    
    func testStreamFSMAppClose() async throws {
        var machine = makeStreamStateMachine()
        _ = machine.process(.appSend) // idle → open
        
        let effects = machine.process(.appClose)
        XCTAssertTrue(effects.contains { if case .emitFrame = $0 { return true }; return false })
    }
    
    func testStreamFSMReset() async throws {
        var machine = makeStreamStateMachine()
        _ = machine.process(.appSend) // idle → open
        
        let effects = machine.process(.resetReceived)
        XCTAssertTrue(effects.contains { if case .markClosed = $0 { return true }; return false })
    }
}
