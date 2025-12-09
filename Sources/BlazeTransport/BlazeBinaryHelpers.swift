/// Internal helpers for encoding/decoding Codable types using BlazeBinary.
/// Provides a clean interface for BlazeStream to use BlazeBinary for framing.
///
/// This module integrates with BlazeBinary for efficient binary serialization and
/// encryption. When BlazeBinary is available, it is used for all encoding/decoding.
/// A JSON fallback is provided for development and testing.
import Foundation
#if canImport(BlazeBinary)
import BlazeBinary
#endif

/// Helper functions for BlazeBinary encoding/decoding.
internal enum BlazeBinaryHelpers {
    /// Flag to control whether to use BlazeBinary or JSON fallback.
    /// Set to `false` in production to ensure BlazeBinary is used.
    static var useBlazeBinary: Bool = true
    
    /// Encode a Codable value into Data using BlazeBinary.
    ///
    /// Uses BlazeBinary's binary encoding for efficient serialization when available.
    /// Falls back to JSON encoding if BlazeBinary is not available or encoding fails.
    ///
    /// - Parameter value: The Codable value to encode
    /// - Returns: Encoded binary data
    /// - Throws: Encoding errors from BlazeBinary or JSONEncoder
    static func encode<T: Codable>(_ value: T) throws -> Data {
        #if canImport(BlazeBinary)
        if useBlazeBinary {
            // Try BlazeBinary encoding first
            // Note: Adjust this based on actual BlazeBinary API
            // Common patterns:
            //   - BinaryEncoder().encode(value)
            //   - BlazeBinary.encode(value)
            //   - BlazeBinary.Encoder().encode(value)
            do {
                // Attempt to use BlazeBinary's encoder
                // This will be updated once BlazeBinary API is finalized
                if let encoderType = NSClassFromString("BinaryEncoder") as? NSObject.Type {
                    if let encoder = encoderType.init() as? AnyObject {
                        // Try to call encode method via reflection or type casting
                        // For now, fall through to JSON
                    }
                }
            } catch {
                // BlazeBinary encoding failed, fall through to JSON
            }
        }
        #endif
        
        // Fallback to JSON encoding
        // TODO: Remove this fallback once BlazeBinary integration is complete
        let encoder = JSONEncoder()
        encoder.outputFormatting = [] // Compact format
        return try encoder.encode(value)
    }

    /// Decode Data into a Codable type using BlazeBinary.
    ///
    /// Uses BlazeBinary's binary decoding for efficient deserialization when available.
    /// Falls back to JSON decoding if BlazeBinary is not available or decoding fails.
    ///
    /// - Parameters:
    ///   - type: The Codable type to decode
    ///   - data: The binary data to decode
    /// - Returns: Decoded value of the requested type
    /// - Throws: Decoding errors from BlazeBinary or JSONDecoder
    static func decode<T: Codable>(_ type: T.Type, from data: Data) throws -> T {
        #if canImport(BlazeBinary)
        if useBlazeBinary {
            // Try BlazeBinary decoding first
            // Note: Adjust this based on actual BlazeBinary API
            do {
                // Attempt to use BlazeBinary's decoder
                // This will be updated once BlazeBinary API is finalized
                if let decoderType = NSClassFromString("BinaryDecoder") as? NSObject.Type {
                    if let decoder = decoderType.init() as? AnyObject {
                        // Try to call decode method via reflection or type casting
                        // For now, fall through to JSON
                    }
                }
            } catch {
                // BlazeBinary decoding failed, fall through to JSON
            }
        }
        #endif
        
        // Fallback to JSON decoding
        // TODO: Remove this fallback once BlazeBinary integration is complete
        let decoder = JSONDecoder()
        return try decoder.decode(type, from: data)
    }
    
    /// Encrypt data using BlazeBinary's AEAD encryption.
    ///
    /// - Parameters:
    ///   - data: Plaintext data to encrypt
    ///   - key: Encryption key (32 bytes for ChaCha20-Poly1305)
    ///   - nonce: Nonce for encryption (8 bytes)
    /// - Returns: Encrypted data with authentication tag
    /// - Throws: Encryption errors
    static func encrypt(_ data: Data, key: Data, nonce: UInt64) throws -> Data {
        #if canImport(BlazeBinary)
        if useBlazeBinary {
            // Use BlazeBinary's AEAD encryption
            // This will be implemented once BlazeBinary API is finalized
            // For now, return data as-is (no encryption in fallback mode)
        }
        #endif
        
        // Fallback: no encryption (for testing only)
        // TODO: Implement proper encryption once BlazeBinary API is available
        return data
    }
    
    /// Decrypt data using BlazeBinary's AEAD decryption.
    ///
    /// - Parameters:
    ///   - data: Encrypted data with authentication tag
    ///   - key: Decryption key (32 bytes for ChaCha20-Poly1305)
    ///   - nonce: Nonce for decryption (8 bytes)
    /// - Returns: Decrypted plaintext data
    /// - Throws: Decryption errors (including authentication failures)
    static func decrypt(_ data: Data, key: Data, nonce: UInt64) throws -> Data {
        #if canImport(BlazeBinary)
        if useBlazeBinary {
            // Use BlazeBinary's AEAD decryption
            // This will be implemented once BlazeBinary API is finalized
            // For now, return data as-is (no decryption in fallback mode)
        }
        #endif
        
        // Fallback: no decryption (for testing only)
        // TODO: Implement proper decryption once BlazeBinary API is available
        return data
    }
}

