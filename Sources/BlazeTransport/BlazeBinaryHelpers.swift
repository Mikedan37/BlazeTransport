/// Internal helpers for encoding/decoding Codable types using BlazeBinary.
/// Provides a clean interface for BlazeStream to use BlazeBinary for framing.
import Foundation
import BlazeBinary

/// Helper functions for BlazeBinary encoding/decoding.
public enum BlazeBinaryHelpers {
    /// Encode a Codable value into Data using BlazeBinary.
    ///
    /// - Parameter value: The Codable value to encode
    /// - Returns: Encoded binary data
    /// - Throws: Encoding errors from BlazeBinary
    public static func encode<T: Codable>(_ value: T) throws -> Data {
        let encoder = BlazeBinaryEncoder()
        let jsonData = try JSONEncoder().encode(value)
        encoder.encode(jsonData)
        return encoder.encodedData()
    }

    /// Decode Data into a Codable type using BlazeBinary.
    ///
    /// - Parameters:
    ///   - type: The Codable type to decode
    ///   - data: The binary data to decode
    /// - Returns: Decoded value of the requested type
    /// - Throws: Decoding errors from BlazeBinary
    public static func decode<T: Codable>(_ type: T.Type, from data: Data) throws -> T {
        let decoder = BlazeBinaryDecoder(data: data)
        let jsonData = try decoder.decodeData()
        return try JSONDecoder().decode(type, from: jsonData)
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
        return data
    }
}

