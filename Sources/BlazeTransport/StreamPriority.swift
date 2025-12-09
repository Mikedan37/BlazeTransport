/// Stream prioritization: assigns weights to streams for fair scheduling.
/// Implements a simple priority queue for stream selection.
import Foundation

/// Stream priority weight (higher = more priority).
typealias StreamWeight = Int

/// Priority queue for stream scheduling.
internal struct StreamPriorityQueue {
    private var streams: [(streamID: UInt32, weight: StreamWeight)] = []
    
    /// Add or update a stream with a priority weight.
    mutating func add(streamID: UInt32, weight: StreamWeight) {
        // Remove if exists
        streams.removeAll { $0.streamID == streamID }
        
        // Insert in sorted order (highest weight first)
        let index = streams.firstIndex { $0.weight < weight } ?? streams.count
        streams.insert((streamID, weight), at: index)
    }
    
    /// Remove a stream from the queue.
    mutating func remove(streamID: UInt32) {
        streams.removeAll { $0.streamID == streamID }
    }
    
    /// Get the next stream to process (highest priority).
    mutating func next() -> UInt32? {
        return streams.isEmpty ? nil : streams.removeFirst().streamID
    }
    
    /// Get all streams in priority order.
    func getAll() -> [UInt32] {
        return streams.map { $0.streamID }
    }
    
    /// Check if queue is empty.
    var isEmpty: Bool {
        return streams.isEmpty
    }
}

/// Default stream weights.
internal enum StreamPriority {
    static let defaultWeight: StreamWeight = 100
    static let highPriorityWeight: StreamWeight = 200
    static let lowPriorityWeight: StreamWeight = 50
    static let controlStreamWeight: StreamWeight = 300  // Highest priority for control
}

