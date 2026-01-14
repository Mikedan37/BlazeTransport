import XCTest
@testable import BlazeTransport
import Foundation

/// Tests for key rotation and security management.
final class KeyRotationTests: XCTestCase {
    
    func testKeyRotationAfterPackets() async throws {
        var security = SecurityManager(maxPacketsPerKey: 10, maxTimePerKey: 3600)
        
        // Generate packets up to limit
        for _ in 0..<9 {
            _ = security.nextNonce()
            XCTAssertFalse(security.shouldRotateKey(now: Date()))
        }
        
        // 10th packet should trigger rotation
        _ = security.nextNonce()
        XCTAssertTrue(security.shouldRotateKey(now: Date()))
    }
    
    func testKeyRotationAfterTime() async throws {
        var security = SecurityManager(maxPacketsPerKey: 1_000_000, maxTimePerKey: 0.1)  // 100ms
        
        XCTAssertFalse(security.shouldRotateKey(now: Date()))
        
        // Wait for rotation time
        try await Task.sleep(for: .milliseconds(150))
        
        XCTAssertTrue(security.shouldRotateKey(now: Date()))
    }
    
    func testKeyRotationResetsNonce() async throws {
        var security = SecurityManager()
        
        // Generate some nonces
        let nonce1 = security.nextNonce()
        let nonce2 = security.nextNonce()
        XCTAssertTrue(nonce2 > nonce1)
        
        // Rotate key
        let newKey = Data(repeating: 0xFF, count: 32)
        security.rotateKey(newKey: newKey)
        
        // Nonce should reset
        let nonce3 = security.nextNonce()
        XCTAssertEqual(nonce3, 0)
    }
    
    func testReplayProtection() async throws {
        var security = SecurityManager()
        
        let nonce1: UInt64 = 100
        let nonce2: UInt64 = 101
        let nonce3: UInt64 = 100  // Duplicate
        
        XCTAssertTrue(security.validateNonce(nonce1))
        XCTAssertTrue(security.validateNonce(nonce2))
        XCTAssertFalse(security.validateNonce(nonce3))  // Replay detected
    }
    
    func testReplayProtectionWindow() async throws {
        var security = SecurityManager()
        
        // Set largest seen nonce to high value
        let largeNonce: UInt64 = 10000
        XCTAssertTrue(security.validateNonce(largeNonce))
        
        // Old nonce outside window should be rejected
        let oldNonce: UInt64 = 1000  // 9000 packets ago, outside 1000 packet window
        XCTAssertFalse(security.validateNonce(oldNonce))
    }
    
    func testReplayProtectionWindowValid() async throws {
        var security = SecurityManager()
        
        let largeNonce: UInt64 = 10000
        XCTAssertTrue(security.validateNonce(largeNonce))
        
        // Nonce within window should be valid
        let recentNonce: UInt64 = 9500  // 500 packets ago, within 1000 packet window
        XCTAssertTrue(security.validateNonce(recentNonce))
    }
}
