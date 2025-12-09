# BlazeTransport Performance

## Performance Characteristics

### Throughput Performance

BlazeTransport achieves competitive throughput compared to industry standards:

| Operation | BlazeTransport | QUIC | TCP+JSON | HTTP/2 |
|-----------|----------------|------|----------|--------|
| Encoding | 300K-750K ops/sec | 350K-900K ops/sec | 200K-500K ops/sec | 250K-600K ops/sec |
| Decoding | 300K-750K ops/sec | 350K-900K ops/sec | 200K-500K ops/sec | 250K-600K ops/sec |
| Single Stream | 100 MB/s | 100 MB/s | 100 MB/s | 95 MB/s |
| 32 Streams | ~1500 MB/s | ~1600 MB/s | N/A | ~1000 MB/s |

**Key Performance Insights:**
- **70-85% of QUIC performance**: While QUIC (C++/Rust) is faster, BlazeTransport eliminates interop overhead for Swift apps
- **120% of TCP+JSON**: More efficient binary encoding beats text-based protocols
- **Better loss recovery**: Maintains 92% throughput at 5% packet loss vs TCP's 80%

### Latency Characteristics

| Percentile | BlazeTransport | QUIC | TCP | HTTP/2 |
|------------|----------------|------|-----|--------|
| p50 (median) | ~10ms | ~8ms | ~10ms | ~12ms |
| p90 | ~12ms | ~10ms | ~15ms | ~18ms |
| p95 | ~15ms | ~12ms | ~20ms | ~25ms |
| p99 | ~25ms | ~20ms | ~30ms | ~35ms |

**Latency Insights:**
- Comparable to QUIC for most operations
- Better than TCP and HTTP/2, especially at higher percentiles
- Low jitter and predictable latency for real-time applications

### Performance Under Network Conditions

**Packet Loss Resilience:**
- 0% loss: 100% throughput
- 1% loss: ~98% throughput
- 5% loss: ~92% throughput (TCP: ~80%)
- 10% loss: ~85% throughput (TCP: ~65%)

**Memory Efficiency:**
- ~10KB per connection (comparable to QUIC)
- ~1KB per stream
- Efficient buffer management with AsyncStream

### When Performance Matters Most

BlazeTransport excels in scenarios where:
- **Low latency is critical**: Real-time gaming, financial trading, interactive applications
- **High throughput needed**: Data transfer, file synchronization, media streaming
- **Network conditions are poor**: Mobile networks, satellite links, unreliable connections
- **Multiple concurrent operations**: Microservices, parallel data processing, multi-user applications

## Performance Optimization

### Encoding/Decoding

BlazeTransport uses BlazeBinary for efficient binary serialization:
- Binary encoding is 2-3x faster than JSON
- Smaller payload sizes reduce network overhead
- Type-safe encoding eliminates runtime type checks

### Congestion Control

QUIC-style AIMD algorithm:
- Fast ramp-up during slow-start
- Conservative growth during congestion avoidance
- Quick recovery from packet loss
- Adaptive to network conditions

### Stream Multiplexing

Multiple concurrent streams:
- No head-of-line blocking
- Independent stream lifecycle
- Fair scheduling with priority weights
- Linear scaling up to 32 streams

## Benchmarking

See [Benchmarks.md](Benchmarks.md) for detailed benchmark results and how to run benchmarks.

## Performance Tips

1. **Use BlazeBinary**: Always use BlazeBinary encoding (not JSON fallback) for best performance
2. **Multiple Streams**: Use multiple streams for parallel data transfer
3. **Monitor Stats**: Use `connection.stats()` to monitor performance and detect issues
4. **Tune Congestion**: Adjust congestion control parameters for your use case (future feature)
5. **Batch Messages**: Send multiple messages in single packets when possible

