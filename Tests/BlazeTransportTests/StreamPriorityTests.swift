import XCTest
@testable import BlazeTransport

/// Tests for stream prioritization functionality.
final class StreamPriorityTests: XCTestCase {
    
    func testStreamPriorityOrdering() async throws {
        var queue = StreamPriorityQueue()
        
        queue.add(streamID: 1, weight: 50)
        queue.add(streamID: 2, weight: 100)
        queue.add(streamID: 3, weight: 200)
        
        // Should return highest weight first
        let first = queue.next()
        XCTAssertEqual(first, 3)  // Weight 200
        
        let second = queue.next()
        XCTAssertEqual(second, 2)  // Weight 100
        
        let third = queue.next()
        XCTAssertEqual(third, 1)  // Weight 50
    }
    
    func testStreamPriorityUpdate() async throws {
        var queue = StreamPriorityQueue()
        
        queue.add(streamID: 1, weight: 50)
        queue.add(streamID: 2, weight: 100)
        
        // Update stream 1 to higher priority
        queue.add(streamID: 1, weight: 150)
        
        let first = queue.next()
        XCTAssertEqual(first, 1)  // Now highest priority
    }
    
    func testStreamPriorityRemove() async throws {
        var queue = StreamPriorityQueue()
        
        queue.add(streamID: 1, weight: 100)
        queue.add(streamID: 2, weight: 200)
        queue.add(streamID: 3, weight: 150)
        
        queue.remove(streamID: 2)
        
        let first = queue.next()
        XCTAssertEqual(first, 3)  // Should be next highest after removing 2
        
        let second = queue.next()
        XCTAssertEqual(second, 1)
    }
    
    func testDefaultStreamWeights() async throws {
        XCTAssertEqual(StreamPriority.defaultWeight, 100)
        XCTAssertEqual(StreamPriority.highPriorityWeight, 200)
        XCTAssertEqual(StreamPriority.lowPriorityWeight, 50)
        XCTAssertEqual(StreamPriority.controlStreamWeight, 300)
        
        // Control stream should have highest priority
        XCTAssertTrue(StreamPriority.controlStreamWeight > StreamPriority.highPriorityWeight)
        XCTAssertTrue(StreamPriority.highPriorityWeight > StreamPriority.defaultWeight)
        XCTAssertTrue(StreamPriority.defaultWeight > StreamPriority.lowPriorityWeight)
    }
}
