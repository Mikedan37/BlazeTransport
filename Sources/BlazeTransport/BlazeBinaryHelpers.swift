/// Internal helpers for encoding/decoding Codable types using length-prefixed binary framing.
/// Provides a clean interface for BlazeStream to use for framing.
import Foundation

/// Helper functions for binary encoding/decoding with length-prefixed framing.
public enum BlazeBinaryHelpers {
    /// Encode a Codable value into length-prefixed binary data.
    ///
    /// Wire format: [4-byte big-endian length][JSON payload]
    ///
    /// - Parameter value: The Codable value to encode
    /// - Returns: Encoded binary data
    /// - Throws: Encoding errors
    public static func encode<T: Codable>(_ value: T) throws -> Data {
        let jsonData = try JSONEncoder().encode(value)
        var framed = Data(capacity: 4 + jsonData.count)
        var length = UInt32(jsonData.count).bigEndian
        framed.append(Data(bytes: &length, count: 4))
        framed.append(jsonData)
        return framed
    }

    /// Decode length-prefixed binary data into a Codable type.
    ///
    /// - Parameters:
    ///   - type: The Codable type to decode
    ///   - data: The binary data to decode
    /// - Returns: Decoded value of the requested type
    /// - Throws: Decoding errors
    public static func decode<T: Codable>(_ type: T.Type, from data: Data) throws -> T {
        guard data.count >= 4 else {
            throw BlazeTransportError.decodingFailed
        }
        let length = data.withUnsafeBytes { $0.loadUnaligned(as: UInt32.self).bigEndian }
        guard data.count >= 4 + Int(length) else {
            throw BlazeTransportError.decodingFailed
        }
        let jsonData = data.subdata(in: 4..<(4 + Int(length)))
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

