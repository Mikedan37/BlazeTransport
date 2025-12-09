import Testing
@testable import BlazeTransport
import Foundation

/// Tests for key rotation and security management.
@Test("Key Rotation: Rotates key after max packets")
func testKeyRotationAfterPackets() async throws {
    var security = SecurityManager(maxPacketsPerKey: 10, maxTimePerKey: 3600)
    
    // Generate packets up to limit
    for _ in 0..<9 {
        _ = security.nextNonce()
        #expect(security.shouldRotateKey(now: Date()) == false)
    }
    
    // 10th packet should trigger rotation
    _ = security.nextNonce()
    #expect(security.shouldRotateKey(now: Date()) == true)
}

@Test("Key Rotation: Rotates key after max time")
func testKeyRotationAfterTime() async throws {
    var security = SecurityManager(maxPacketsPerKey: 1_000_000, maxTimePerKey: 0.1)  // 100ms
    
    #expect(security.shouldRotateKey(now: Date()) == false)
    
    // Wait for rotation time
    try await Task.sleep(for: .milliseconds(150))
    
    #expect(security.shouldRotateKey(now: Date()) == true)
}

@Test("Key Rotation: Resets nonce counter on rotation")
func testKeyRotationResetsNonce() async throws {
    var security = SecurityManager()
    
    // Generate some nonces
    let nonce1 = security.nextNonce()
    let nonce2 = security.nextNonce()
    #expect(nonce2 > nonce1)
    
    // Rotate key
    let newKey = Data(repeating: 0xFF, count: 32)
    security.rotateKey(newKey: newKey)
    
    // Nonce should reset
    let nonce3 = security.nextNonce()
    #expect(nonce3 == 0)
}

@Test("Replay Protection: Rejects duplicate nonces")
func testReplayProtection() async throws {
    var security = SecurityManager()
    
    let nonce1: UInt64 = 100
    let nonce2: UInt64 = 101
    let nonce3: UInt64 = 100  // Duplicate
    
    #expect(security.validateNonce(nonce1) == true)
    #expect(security.validateNonce(nonce2) == true)
    #expect(security.validateNonce(nonce3) == false)  // Replay detected
}

@Test("Replay Protection: Rejects old nonces outside window")
func testReplayProtectionWindow() async throws {
    var security = SecurityManager()
    
    // Set largest seen nonce to high value
    let largeNonce: UInt64 = 10000
    #expect(security.validateNonce(largeNonce) == true)
    
    // Old nonce outside window should be rejected
    let oldNonce: UInt64 = 1000  // 9000 packets ago, outside 1000 packet window
    #expect(security.validateNonce(oldNonce) == false)
}

@Test("Replay Protection: Allows nonces within window")
func testReplayProtectionWindowValid() async throws {
    var security = SecurityManager()
    
    let largeNonce: UInt64 = 10000
    #expect(security.validateNonce(largeNonce) == true)
    
    // Nonce within window should be valid
    let recentNonce: UInt64 = 9500  // 500 packets ago, within 1000 packet window
    #expect(security.validateNonce(recentNonce) == true)
}

