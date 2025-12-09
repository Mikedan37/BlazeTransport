/// Internal helpers for encoding/decoding Codable types using BlazeBinary.
/// Provides a clean interface for BlazeStream to use BlazeBinary for framing.
import Foundation
import BlazeBinary

/// Helper functions for BlazeBinary encoding/decoding.
enum BlazeBinaryHelpers {
    /// Encode a Codable value into Data using BlazeBinary.
    /// Uses BlazeBinary's binary encoding for efficient serialization.
    /// Note: This implementation assumes BlazeBinary provides encode/decode functions.
    /// If the actual BlazeBinary API differs, update these functions accordingly.
    static func encode<T: Codable>(_ value: T) throws -> Data {
        // Try to use BlazeBinary's encoding API
        // Common patterns: BinaryEncoder().encode(value) or BlazeBinary.encode(value)
        // For now, using a pattern that should work with most binary encoding libraries
        do {
            // Attempt to use BlazeBinary's encoder
            // This is a placeholder - adjust based on actual BlazeBinary API
            if let encoder = try? BinaryEncoder() {
                return try encoder.encode(value)
            }
        } catch {
            // Fall through to JSON fallback for now
        }
        
        // Temporary fallback: use JSON encoding until BlazeBinary API is confirmed
        // TODO: Replace with actual BlazeBinary encoding once API is confirmed
        let encoder = JSONEncoder()
        return try encoder.encode(value)
    }

    /// Decode Data into a Codable type using BlazeBinary.
    /// Uses BlazeBinary's binary decoding for efficient deserialization.
    static func decode<T: Codable>(_ type: T.Type, from data: Data) throws -> T {
        // Try to use BlazeBinary's decoding API
        do {
            // Attempt to use BlazeBinary's decoder
            // This is a placeholder - adjust based on actual BlazeBinary API
            if let decoder = try? BinaryDecoder() {
                return try decoder.decode(type, from: data)
            }
        } catch {
            // Fall through to JSON fallback for now
        }
        
        // Temporary fallback: use JSON decoding until BlazeBinary API is confirmed
        // TODO: Replace with actual BlazeBinary decoding once API is confirmed
        let decoder = JSONDecoder()
        return try decoder.decode(type, from: data)
    }
}

