# BlazeTransport

A QUIC-lite Swift-native transport protocol with multi-streaming, reliability, congestion control, and typed messaging. BlazeTransport provides a high-level, type-safe API for establishing connections, opening streams, and sending/receiving Codable messages over a reliable, congestion-controlled transport layer built on UDP. It's designed for Swift applications that need low-latency, reliable message delivery with multiple concurrent streams, built-in encryption, and QUIC-like performance without C interop overhead.

## Quick Start

### Installation

Add BlazeTransport to your `Package.swift`:

```swift
dependencies: [
    .package(url: "https://github.com/Mikedan37/BlazeTransport.git", from: "0.1.0")
]
```

### Minimal Example

```swift
import BlazeTransport

let connection = try await BlazeTransport.connect(
    host: "127.0.0.1",
    port: 9999,
    security: .blazeDefault
)
let stream = try await connection.openStream()
try await stream.send("Hello, Blaze!")
let reply: String = try await stream.receive(String.self)
try await connection.close()
```

See [Examples/](Examples/) for complete echo server and client implementations.

## Features

- **Reliable Message Delivery**: Automatic retransmission, packet sequencing, and RTT estimation
- **Multi-Stream Multiplexing**: Open multiple concurrent streams per connection (up to 32 streams)
- **Type-Safe Messaging**: Send/receive any `Codable` type with automatic encoding/decoding
- **Congestion Control**: AIMD algorithm with QUIC-style RTT smoothing and pacing
- **Integrated Security**: ChaCha20-Poly1305 AEAD encryption with X25519 key exchange
- **Connection Migration**: Support for address changes during connection lifetime
- **Stream Prioritization**: Weight-based scheduling for fair stream processing
- **Performance**: 70-85% of QUIC performance with zero interop cost for Swift apps

## Documentation

Comprehensive documentation is available in the [Docs/](Docs/) directory:

- [Architecture.md](Docs/Architecture.md) - System architecture and design
- [StateMachines.md](Docs/StateMachines.md) - Connection and stream state machines
- [SecurityModel.md](Docs/SecurityModel.md) - Security architecture and threat model
- [QUICComparison.md](Docs/QUICComparison.md) - Comparison with QUIC protocol
- [Performance.md](Docs/Performance.md) - Performance characteristics and benchmarks
- [Benchmarks.md](Docs/Benchmarks.md) - Benchmark suite and results
- [Internals.md](Docs/Internals.md) - Internal implementation details

## When to Use BlazeTransport

**Use BlazeTransport when:**
- Building Swift-native applications requiring reliable, low-latency communication
- Need type-safe messaging with Codable without HTTP/3 complexity
- Want multiple concurrent streams on a single connection
- Require built-in encryption and security
- Need to customize protocol behavior for specific use cases

**Consider alternatives when:**
- Need maximum performance (QUIC C++ implementations are faster)
- Require HTTP/3 support (use QUIC directly)
- Need 0-RTT handshakes (planned for v0.3+)
- Want battle-tested protocol with large deployment base (use QUIC or TCP+TLS)

## Limitations (v0.1)

- **No 0-RTT**: Zero round-trip time handshakes not supported (planned for v0.3+)
- **No HTTP/3**: HTTP/3 support not included (use QUIC directly if needed)
- **Simplified Handshake**: Uses X25519 + AEAD, not certificate-based authentication
- **Basic Prioritization**: Stream prioritization is weight-based but simple
- **No DDoS Protection**: No built-in rate limiting or DDoS mitigation
- **User-Space Only**: No kernel bypass, uses standard UDP sockets

## Roadmap (v0.2–v0.5)

**v0.2** (Planned):
- 0-RTT handshakes
- Enhanced stream prioritization algorithms
- Certificate-based authentication
- Performance optimizations

**v0.3** (Planned):
- HTTP/3 support
- WebSocket over BlazeTransport
- Advanced congestion control algorithms
- Multi-path support

**v0.4** (Planned):
- Cross-platform support (Linux, Windows)
- IPv6 support
- Advanced rate limiting
- Connection pooling

**v0.5** (Planned):
- Production hardening
- Advanced monitoring and observability
- Performance profiling tools
- Comprehensive fuzzing

## Requirements

- Swift 6.0+
- macOS 14.0+ / iOS 17.0+
- BlazeBinary (for encoding/encryption)
- BlazeFSM (for state machines)
- BlazeDB (optional, for protocol hooks)

## Testing

Run tests with:

```bash
swift test
```

Run benchmarks with:

```bash
swift run BlazeTransportBenchmarks --all
```

## License

This project is licensed under the MIT License - see the [LICENSE](LICENSE) file for details.
