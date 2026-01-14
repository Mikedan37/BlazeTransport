import XCTest
@testable import BlazeTransport

/// Tests for connection migration functionality.
final class ConnectionMigrationTests: XCTestCase {
    
    func testConnectionMigrationTracking() async throws {
        let migration = ConnectionMigration(host: "127.0.0.1", port: 9999)
        
        XCTAssertFalse(migration.hasAddressChanged(host: "127.0.0.1", port: 9999))
        XCTAssertTrue(migration.hasAddressChanged(host: "127.0.0.1", port: 10000))
        XCTAssertTrue(migration.hasAddressChanged(host: "192.168.1.1", port: 9999))
    }
    
    func testValidMigration() async throws {
        var migration = ConnectionMigration(host: "127.0.0.1", port: 9999)
        
        let result = migration.migrate(to: "192.168.1.1", port: 10000)
        XCTAssertTrue(result)
        XCTAssertFalse(migration.hasAddressChanged(host: "192.168.1.1", port: 10000))
    }
    
    func testAddressValidation() async throws {
        var migration = ConnectionMigration(host: "127.0.0.1", port: 9999)
        
        // Original address should be valid
        XCTAssertTrue(migration.validateAddress(host: "127.0.0.1", port: 9999))
        
        // Migrate to new address
        _ = migration.migrate(to: "192.168.1.1", port: 10000)
        
        // Both original and new address should be valid
        XCTAssertTrue(migration.validateAddress(host: "127.0.0.1", port: 9999))
        XCTAssertTrue(migration.validateAddress(host: "192.168.1.1", port: 10000))
        
        // Unrelated address should be invalid
        XCTAssertFalse(migration.validateAddress(host: "10.0.0.1", port: 9999))
    }
    
    func testMigrationRateLimit() async throws {
        var migration = ConnectionMigration(host: "127.0.0.1", port: 9999)
        
        // First migration should succeed
        let result1 = migration.migrate(to: "192.168.1.1", port: 10000)
        XCTAssertTrue(result1)
        
        // Immediate second migration should fail (rate limited)
        let result2 = migration.migrate(to: "192.168.1.2", port: 10001)
        XCTAssertFalse(result2)
    }
    
    func testMigrationLimit() async throws {
        var migration = ConnectionMigration(host: "127.0.0.1", port: 9999)
        
        // Perform multiple migrations with delays
        for i in 0..<10 {
            let result = migration.migrate(to: "192.168.1.\(i+1)", port: UInt16(10000 + i))
            XCTAssertTrue(result)
            try await Task.sleep(for: .milliseconds(1100))  // Wait > 1 second
        }
        
        // 11th migration should fail (limit reached)
        let result = migration.migrate(to: "192.168.1.11", port: 10010)
        XCTAssertFalse(result)
    }
}
