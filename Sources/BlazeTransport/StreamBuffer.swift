/// Internal stream buffer for managing per-stream data delivery.
/// Uses AsyncStream to provide backpressure-aware data delivery.
import Foundation

/// Actor managing per-stream data buffers using AsyncStream.
actor StreamBuffer {
    private var buffers: [UInt32: AsyncStream<Data>.Continuation] = [:]
    private var closedStreams: Set<UInt32> = []

    /// Register a stream and return its AsyncStream for receiving data.
    func register(streamID: UInt32) -> AsyncStream<Data> {
        return AsyncStream { continuation in
            buffers[streamID] = continuation
        }
    }

    /// Deliver data to a stream's buffer.
    func deliver(streamID: UInt32, data: Data) {
        guard let continuation = buffers[streamID], !closedStreams.contains(streamID) else {
            return
        }
        continuation.yield(data)
    }

    /// Mark a stream as closed and finish its continuation.
    func close(streamID: UInt32) {
        guard let continuation = buffers.removeValue(forKey: streamID) else {
            return
        }
        closedStreams.insert(streamID)
        continuation.finish()
    }

    /// Unregister a stream (cleanup).
    func unregister(streamID: UInt32) {
        buffers.removeValue(forKey: streamID)
        closedStreams.remove(streamID)
    }
}

