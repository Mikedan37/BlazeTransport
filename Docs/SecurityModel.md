# BlazeTransport Security Model

This document describes BlazeTransport's security architecture, threat model, failure modes, and security guarantees. For implementation details, see [SECURITY.md](../SECURITY.md).

## Security Architecture

### Encryption

BlazeTransport uses **Authenticated Encryption with Associated Data (AEAD)** via ChaCha20-Poly1305:

- **Algorithm**: ChaCha20-Poly1305 (RFC 8439)
- **Key Size**: 256 bits (32 bytes)
- **Nonce Size**: 64 bits (8 bytes)
- **Authentication Tag**: 128 bits (16 bytes)

All application data and protocol frames are encrypted before transmission. Only packet headers remain unencrypted (for routing purposes).

### Key Exchange

BlazeTransport uses **X25519 elliptic curve Diffie-Hellman** for key exchange:

- **Algorithm**: X25519 (Curve25519)
- **Key Size**: 256 bits (32 bytes)
- **Ephemeral Keys**: New key pair generated for each connection
- **Perfect Forward Secrecy**: Past communications remain secure even if long-term keys are compromised

### Key Rotation

Keys are automatically rotated to limit exposure:

- **Packet-based rotation**: After 1,000,000 packets (configurable)
- **Time-based rotation**: After 1 hour (configurable)
- **Automatic rotation**: Checked on each ACK received
- **Nonce reset**: Nonce counter resets to 0 after rotation

### Replay Protection

BlazeTransport implements comprehensive replay protection:

- **Replay Window**: 1000 packets (configurable)
- **Nonce-based detection**: Each packet includes a unique nonce
- **Automatic rejection**: Replayed packets are rejected before processing
- **Window management**: Old nonces outside the window are automatically pruned

## Threat Model

### Threats Defended Against

#### 1. Eavesdropping (Confidentiality)

**Threat**: Attacker intercepts network traffic and reads data.

**Mitigation**: All data encrypted with ChaCha20-Poly1305 AEAD. Without the encryption key, intercepted data is indistinguishable from random noise.

**Guarantee**: Eavesdroppers cannot read application data or protocol frames.

#### 2. Tampering (Integrity)

**Threat**: Attacker modifies packets in transit.

**Mitigation**: Every packet includes a Poly1305 authentication tag. Modified packets fail authentication and are rejected.

**Guarantee**: Any modification to encrypted data is detected and the packet is rejected.

#### 3. Replay Attacks

**Threat**: Attacker captures and retransmits old packets.

**Mitigation**: 
- Packet sequence numbers prevent replay
- Nonce-based replay window tracks seen nonces
- Connection IDs prevent cross-connection replay

**Guarantee**: Replayed packets are rejected before reaching the application.

#### 4. Man-in-the-Middle (MITM)

**Threat**: Attacker intercepts and modifies communication between peers.

**Mitigation**: 
- X25519 key exchange with proper validation prevents MITM
- Perfect Forward Secrecy ensures past communications remain secure
- AEAD authentication detects any tampering

**Guarantee**: MITM attacks are prevented by cryptographic authentication.

#### 5. Connection Hijacking

**Threat**: Attacker takes over an established connection.

**Mitigation**: 
- Cryptographic authentication required for all packets
- Connection IDs prevent hijacking
- Key rotation limits exposure window

**Guarantee**: Connection hijacking requires breaking encryption, which is computationally infeasible.

### Threats NOT Defended Against

BlazeTransport is a **transport protocol** and does NOT defend against:

1. **Application-level attacks**: SQL injection, XSS, etc. (application responsibility)
2. **DDoS attacks**: No built-in rate limiting or DDoS mitigation
3. **Traffic analysis**: Packet sizes and timing patterns may leak information
4. **Denial of Service**: Resource exhaustion attacks (application responsibility)
5. **Social engineering**: User authentication and authorization (application responsibility)

## Failure Modes

### AEAD Decryption Failure

**When it occurs**: Authentication tag mismatch during decryption.

**Behavior**:
- Packet is silently dropped
- No error propagated to application (prevents timing attacks)
- Connection continues normally
- Statistics may track failure rate (future feature)

**Security implications**:
- Indicates tampering or corruption
- Repeated failures may indicate an attack
- Applications should monitor connection health

### Replay Detection

**When it occurs**: Nonce is outside replay window or has been seen before.

**Behavior**:
- Packet is rejected before decryption
- No error propagated to application
- Connection continues normally

**Security implications**:
- Legitimate out-of-order packets may be rejected if outside window
- Window size balances security vs. tolerance for reordering

### Key Rotation Failure

**When it occurs**: Key rotation is triggered but new key cannot be established.

**Behavior**:
- Connection may be closed if key rotation is mandatory
- Fallback to old key if rotation is optional (not recommended)
- Error propagated to application

**Security implications**:
- Old key remains in use, increasing exposure
- Applications should close connection and re-establish

### Handshake Failure

**When it occurs**: Cryptographic handshake cannot complete.

**Behavior**:
- Connection is closed
- `BlazeTransportError.handshakeFailed` is thrown
- No data is transmitted

**Security implications**:
- Prevents connection with unauthenticated peers
- May indicate network issues or attack

## Replay Protection Model

### Nonce Management

Each packet includes a 64-bit nonce that must be unique within the replay window:

1. **Sender**: Increments nonce for each packet sent
2. **Receiver**: Validates nonce against replay window
3. **Window**: Tracks last 1000 nonces seen
4. **Rejection**: Nonces outside window or already seen are rejected

### Window Size

The replay window size (default: 1000 packets) balances:

- **Security**: Larger window = more tolerance for reordering
- **Memory**: Larger window = more memory usage
- **Performance**: Larger window = more validation overhead

### Out-of-Order Tolerance

BlazeTransport tolerates out-of-order delivery within the replay window:

- Packets arriving out of order are accepted if nonce is within window
- Packets arriving too late (outside window) are rejected
- This prevents replay while allowing legitimate reordering

## AEAD Error-Handling Policy

### Silent Failure

AEAD decryption failures are handled silently:

- **Rationale**: Prevents timing attacks that could reveal information
- **Behavior**: Packet is dropped, no error propagated
- **Monitoring**: Applications can monitor connection stats for anomalies

### Error Propagation

Only non-security errors are propagated:

- **Network errors**: Connection failures, timeouts
- **Protocol errors**: Invalid packet format, version mismatch
- **Application errors**: Encoding/decoding failures

Security-related errors (AEAD failures, replay detection) are handled internally.

## Security Best Practices

### For Application Developers

1. **Always use `.blazeDefault` security** in production
2. **Implement application-level authentication** for user identity
3. **Validate certificates** if using certificate-based authentication
4. **Monitor connection statistics** for anomalies
5. **Rotate keys periodically** for long-lived connections (automatic in BlazeTransport)
6. **Keep dependencies updated** (BlazeBinary, BlazeFSM)
7. **Use rate limiting** at the application layer to prevent abuse

### For Security Auditors

1. **Review key rotation policy**: Ensure rotation occurs frequently enough
2. **Verify replay window size**: Balance security vs. performance
3. **Check nonce management**: Ensure nonces are never reused
4. **Validate AEAD implementation**: Ensure BlazeBinary uses secure primitives
5. **Review error handling**: Ensure no information leakage

## Security Guarantees

When using `.blazeDefault` security, BlazeTransport guarantees:

- **Confidentiality**: Eavesdroppers cannot read your data
- **Integrity**: Data cannot be modified in transit without detection
- **Authenticity**: You're communicating with the intended peer
- **Replay Protection**: Old messages cannot be replayed
- **Forward Secrecy**: Past communications remain secure

## Comparison with Other Protocols

| Feature | BlazeTransport | QUIC | TLS 1.3 | TCP+TLS |
|---------|----------------|------|---------|---------|
| **Encryption** | ChaCha20-Poly1305 | AES-GCM/ChaCha20 | AES-GCM/ChaCha20 | AES-GCM/ChaCha20 |
| **Key Exchange** | X25519 | ECDHE | ECDHE | ECDHE |
| **Forward Secrecy** | Yes | Yes | Yes | Yes |
| **Replay Protection** | Yes | Yes | Yes | Yes |
| **Integrated Security** | Yes | Yes | No (separate layer) | No (separate layer) |
| **Key Rotation** | Automatic | Automatic | Manual | Manual |

## Conclusion

BlazeTransport provides security equivalent to QUIC or TLS 1.3 through integrated encryption, authentication, and replay protection. The security model is designed to be simple, secure, and suitable for production use with proper application-level authentication.

For most applications, BlazeTransport's security is sufficient. Applications requiring additional security features (e.g., certificate pinning, client authentication) should implement these at the application layer.

