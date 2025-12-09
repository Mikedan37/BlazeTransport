/// Security manager: handles key rotation, replay protection, and nonce management.
/// Provides security hardening for BlazeTransport connections.
import Foundation

/// Manages encryption keys, nonces, and replay protection.
internal struct SecurityManager {
    private(set) var currentKey: Data?
    private(set) var currentNonce: UInt64 = 0
    private(set) var packetsSinceKeyRotation: Int = 0
    private(set) var lastKeyRotationTime: Date?
    
    // Replay protection window
    private var replayWindow: Set<UInt64> = []
    private let replayWindowSize = 1000
    private var largestSeenNonce: UInt64 = 0
    
    // Key rotation policy
    let maxPacketsPerKey: Int = 1_000_000  // Rotate after 1M packets
    let maxTimePerKey: TimeInterval = 3600  // Rotate after 1 hour
    
    init(initialKey: Data? = nil) {
        self.currentKey = initialKey
        self.lastKeyRotationTime = Date()
    }
    
    /// Get current encryption key.
    func getCurrentKey() -> Data? {
        return currentKey
    }
    
    /// Get next nonce for encryption.
    mutating func nextNonce() -> UInt64 {
        let nonce = currentNonce
        currentNonce = currentNonce &+ 1  // Wraps on overflow
        packetsSinceKeyRotation += 1
        return nonce
    }
    
    /// Rotate encryption key.
    mutating func rotateKey(newKey: Data) {
        currentKey = newKey
        currentNonce = 0
        packetsSinceKeyRotation = 0
        lastKeyRotationTime = Date()
        replayWindow.removeAll()
        largestSeenNonce = 0
    }
    
    /// Check if key rotation is needed.
    func shouldRotateKey(now: Date) -> Bool {
        // Rotate if too many packets
        if packetsSinceKeyRotation >= maxPacketsPerKey {
            return true
        }
        
        // Rotate if too much time has passed
        if let lastRotation = lastKeyRotationTime {
            let timeSinceRotation = now.timeIntervalSince(lastRotation)
            if timeSinceRotation >= maxTimePerKey {
                return true
            }
        }
        
        return false
    }
    
    /// Validate nonce for replay protection.
    /// Returns true if nonce is valid (not replayed), false if replay detected.
    mutating func validateNonce(_ nonce: UInt64) -> Bool {
        // Check if nonce is too old (outside replay window)
        if nonce < largestSeenNonce && (largestSeenNonce - nonce) > UInt64(replayWindowSize) {
            return false  // Too old, likely replay
        }
        
        // Check if we've seen this nonce before
        if replayWindow.contains(nonce) {
            return false  // Replay detected
        }
        
        // Update replay window
        if nonce > largestSeenNonce {
            largestSeenNonce = nonce
        }
        
        replayWindow.insert(nonce)
        
        // Trim replay window if too large
        if replayWindow.count > replayWindowSize {
            let oldestNonce = largestSeenNonce - UInt64(replayWindowSize)
            replayWindow = replayWindow.filter { $0 >= oldestNonce }
        }
        
        return true
    }
    
    /// Reset security state (for testing).
    mutating func reset() {
        currentNonce = 0
        packetsSinceKeyRotation = 0
        lastKeyRotationTime = Date()
        replayWindow.removeAll()
        largestSeenNonce = 0
    }
}

