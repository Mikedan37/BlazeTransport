import Testing
@testable import BlazeTransport

/// Tests for stream prioritization functionality.
@Test("Stream Priority: Higher weight streams are selected first")
func testStreamPriorityOrdering() async throws {
    var queue = StreamPriorityQueue()
    
    queue.add(streamID: 1, weight: 50)
    queue.add(streamID: 2, weight: 100)
    queue.add(streamID: 3, weight: 200)
    
    // Should return highest weight first
    let first = queue.next()
    #expect(first == 3)  // Weight 200
    
    let second = queue.next()
    #expect(second == 2)  // Weight 100
    
    let third = queue.next()
    #expect(third == 1)  // Weight 50
}

@Test("Stream Priority: Updating weight changes priority")
func testStreamPriorityUpdate() async throws {
    var queue = StreamPriorityQueue()
    
    queue.add(streamID: 1, weight: 50)
    queue.add(streamID: 2, weight: 100)
    
    // Update stream 1 to higher priority
    queue.add(streamID: 1, weight: 150)
    
    let first = queue.next()
    #expect(first == 1)  // Now highest priority
}

@Test("Stream Priority: Removing stream removes from queue")
func testStreamPriorityRemove() async throws {
    var queue = StreamPriorityQueue()
    
    queue.add(streamID: 1, weight: 100)
    queue.add(streamID: 2, weight: 200)
    queue.add(streamID: 3, weight: 150)
    
    queue.remove(streamID: 2)
    
    let first = queue.next()
    #expect(first == 3)  // Should be next highest after removing 2
    
    let second = queue.next()
    #expect(second == 1)
}

@Test("Stream Priority: Default weights are applied correctly")
func testDefaultStreamWeights() async throws {
    #expect(StreamPriority.defaultWeight == 100)
    #expect(StreamPriority.highPriorityWeight == 200)
    #expect(StreamPriority.lowPriorityWeight == 50)
    #expect(StreamPriority.controlStreamWeight == 300)
    
    // Control stream should have highest priority
    #expect(StreamPriority.controlStreamWeight > StreamPriority.highPriorityWeight)
    #expect(StreamPriority.highPriorityWeight > StreamPriority.defaultWeight)
    #expect(StreamPriority.defaultWeight > StreamPriority.lowPriorityWeight)
}

