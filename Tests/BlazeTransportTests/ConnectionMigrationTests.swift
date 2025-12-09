import Testing
@testable import BlazeTransport

/// Tests for connection migration functionality.
@Test("Connection Migration: Tracks original and current address")
func testConnectionMigrationTracking() async throws {
    var migration = ConnectionMigration(host: "127.0.0.1", port: 9999)
    
    #expect(migration.hasAddressChanged(host: "127.0.0.1", port: 9999) == false)
    #expect(migration.hasAddressChanged(host: "127.0.0.1", port: 10000) == true)
    #expect(migration.hasAddressChanged(host: "192.168.1.1", port: 9999) == true)
}

@Test("Connection Migration: Allows valid migration")
func testValidMigration() async throws {
    var migration = ConnectionMigration(host: "127.0.0.1", port: 9999)
    
    let result = migration.migrate(to: "192.168.1.1", port: 10000)
    #expect(result == true)
    #expect(migration.hasAddressChanged(host: "192.168.1.1", port: 10000) == false)
}

@Test("Connection Migration: Validates incoming packet addresses")
func testAddressValidation() async throws {
    var migration = ConnectionMigration(host: "127.0.0.1", port: 9999)
    
    // Original address should be valid
    #expect(migration.validateAddress(host: "127.0.0.1", port: 9999) == true)
    
    // Migrate to new address
    migration.migrate(to: "192.168.1.1", port: 10000)
    
    // Both original and new address should be valid
    #expect(migration.validateAddress(host: "127.0.0.1", port: 9999) == true)
    #expect(migration.validateAddress(host: "192.168.1.1", port: 10000) == true)
    
    // Unrelated address should be invalid
    #expect(migration.validateAddress(host: "10.0.0.1", port: 9999) == false)
}

@Test("Connection Migration: Rate limits migrations")
func testMigrationRateLimit() async throws {
    var migration = ConnectionMigration(host: "127.0.0.1", port: 9999)
    
    // First migration should succeed
    let result1 = migration.migrate(to: "192.168.1.1", port: 10000)
    #expect(result1 == true)
    
    // Immediate second migration should fail (rate limited)
    let result2 = migration.migrate(to: "192.168.1.2", port: 10001)
    #expect(result2 == false)
}

@Test("Connection Migration: Limits total migrations")
func testMigrationLimit() async throws {
    var migration = ConnectionMigration(host: "127.0.0.1", port: 9999)
    
    // Perform multiple migrations with delays
    for i in 0..<10 {
        let result = migration.migrate(to: "192.168.1.\(i+1)", port: UInt16(10000 + i))
        #expect(result == true)
        try await Task.sleep(for: .milliseconds(1100))  // Wait > 1 second
    }
    
    // 11th migration should fail (limit reached)
    let result = migration.migrate(to: "192.168.1.11", port: 10010)
    #expect(result == false)
}

