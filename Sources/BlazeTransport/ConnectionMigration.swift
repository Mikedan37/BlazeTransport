/// Connection migration support: allows connections to survive address changes.
/// Tracks peer address changes and validates migration attempts.
import Foundation

/// Tracks connection migration state and validates address changes.
internal struct ConnectionMigration {
    private(set) var originalAddress: (host: String, port: UInt16)
    private(set) var currentAddress: (host: String, port: UInt16)
    private(set) var migrationCount: Int = 0
    private(set) var lastMigrationTime: Date?
    
    init(host: String, port: UInt16) {
        self.originalAddress = (host, port)
        self.currentAddress = (host, port)
    }
    
    /// Check if address has changed.
    func hasAddressChanged(host: String, port: UInt16) -> Bool {
        return currentAddress.host != host || currentAddress.port != port
    }
    
    /// Migrate connection to new address.
    /// Returns true if migration is allowed, false if rejected.
    mutating func migrate(to host: String, port: UInt16) -> Bool {
        // Prevent excessive migrations (rate limiting)
        if let lastMigration = lastMigrationTime {
            let timeSinceLastMigration = Date().timeIntervalSince(lastMigration)
            if timeSinceLastMigration < 1.0 { // Minimum 1 second between migrations
                return false
            }
        }
        
        // Limit total migrations per connection
        if migrationCount >= 10 {
            return false
        }
        
        // Update address
        currentAddress = (host, port)
        migrationCount += 1
        lastMigrationTime = Date()
        
        return true
    }
    
    /// Validate that incoming packet is from expected address.
    func validateAddress(host: String, port: UInt16) -> Bool {
        // Allow packets from current address or original address (for migration)
        return (host == currentAddress.host && port == currentAddress.port) ||
               (host == originalAddress.host && port == originalAddress.port)
    }
    
    /// Reset migration state (for testing).
    mutating func reset() {
        currentAddress = originalAddress
        migrationCount = 0
        lastMigrationTime = nil
    }
}

