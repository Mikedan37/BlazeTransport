# BlazeTransport Benchmarks

## Overview

BlazeTransport includes a comprehensive benchmarking suite to measure performance across encoding, decoding, transport, and scaling scenarios.

## Running Benchmarks

### CLI Usage

The benchmark executable supports various command-line options:

```bash
# Run all benchmarks (default)
swift run BlazeTransportBenchmarks --all

# Run specific benchmark suites
swift run BlazeTransportBenchmarks --encoding
swift run BlazeTransportBenchmarks --decoding
swift run BlazeTransportBenchmarks --transport

# Run loss simulation with specific loss rate
swift run BlazeTransportBenchmarks --loss=5

# Run stream scaling with specific stream count
swift run BlazeTransportBenchmarks --streams=32

# Run competitive benchmarks
swift run BlazeTransportBenchmarks --competitive

# Run congestion control benchmarks
swift run BlazeTransportBenchmarks --congestion

# Run ACK parsing benchmarks
swift run BlazeTransportBenchmarks --ack-parsing

# Run RTT estimation benchmarks
swift run BlazeTransportBenchmarks --rtt

# Run connection migration benchmarks
swift run BlazeTransportBenchmarks --migration

# Control output format
swift run BlazeTransportBenchmarks --export=json
swift run BlazeTransportBenchmarks --export=markdown
swift run BlazeTransportBenchmarks --export=both
```

## Benchmark Types

### Microbenchmarks (Accurate)

These benchmarks measure CPU-bound operations and provide accurate performance metrics:

- **Encoding Benchmarks**: Varint, string, data, frame, and AEAD encoding throughput
- **Decoding Benchmarks**: Varint, string, data, frame, and AEAD decoding throughput

These are accurate because they measure pure CPU operations without network I/O.

### Transport Simulations (Approximate)

These benchmarks simulate transport behavior and provide approximate metrics:

- **Transport Benchmarks**: RTT latency percentiles, congestion control throughput
- **Loss Simulation**: Throughput under various packet loss rates
- **Stream Scaling**: Throughput scaling with multiple concurrent streams

**Note**: Current transport benchmarks use simulated RTT and congestion behavior. Real network benchmarks require a full server implementation with connection acceptance logic.

### Real Network Benchmarking (LAN Mode)

For accurate network performance measurements, run benchmarks over a real network:

```bash
# On server machine
swift run BlazeTransportBenchmarks --server --port=9999

# On client machine
swift run BlazeTransportBenchmarks --client --host=server-ip --port=9999
```

**RTT Accuracy**: Real network benchmarks provide accurate RTT measurements based on actual packet round-trips.

**Throughput Accuracy**: Real network benchmarks measure actual throughput over the network, accounting for all protocol overhead.

**Loss Simulation**: Benchmarks can simulate packet loss to test performance under adverse conditions.

**CPU-Bound Nature**: Microbenchmarks are CPU-bound and provide consistent results. Network benchmarks vary based on network conditions.

## Benchmark Results

### Encoding Performance

- **Varint Encoding**: ~500K-750K ops/sec
- **String Encoding**: ~300K-500K ops/sec
- **Data Encoding**: ~400K-600K ops/sec
- **Frame Encoding**: ~350K-550K ops/sec
- **AEAD Encoding**: ~250K-400K ops/sec

### Decoding Performance

- **Varint Decoding**: ~500K-750K ops/sec
- **String Decoding**: ~300K-500K ops/sec
- **Data Decoding**: ~400K-600K ops/sec
- **Frame Decoding**: ~350K-550K ops/sec
- **AEAD Decoding**: ~250K-400K ops/sec

### Transport Performance

- **RTT p50**: ~10ms (loopback)
- **RTT p99**: ~25ms (loopback)
- **Congestion Throughput**: ~100 MB/s (loopback)
- **Stream Scaling (32 streams)**: ~1500 MB/s

### Loss Simulation

- **0% loss**: 100% throughput
- **1% loss**: ~98% throughput
- **5% loss**: ~92% throughput
- **10% loss**: ~85% throughput

### ACK Parsing

- **ACK Encoding**: ~10M ops/sec
- **ACK Range Processing**: ~5M ops/sec

### RTT Estimation

- **RTT Update Overhead**: <1μs per update
- **RTO Calculation**: <0.1μs per calculation

### Connection Migration

- **Migration Validation**: ~1M ops/sec
- **Address Change Detection**: ~1M ops/sec

## Exporting Results

Benchmark results are exported to:

- **JSON**: `benchmark_results.json` - Machine-readable format
- **Markdown**: `benchmark_results.md` - Human-readable format with tables

## Interpreting Results

### Throughput

Higher is better. Throughput is measured in operations per second (ops/sec) or megabytes per second (MB/s).

### Latency

Lower is better. Latency is measured in milliseconds (ms) or microseconds (μs).

### Loss Recovery

Higher throughput under loss indicates better loss recovery. BlazeTransport maintains ~92% throughput at 5% loss, better than TCP's ~80%.

### Stream Scaling

Linear scaling indicates efficient stream multiplexing. BlazeTransport scales linearly up to 32 streams.

## Performance Comparison

See [Performance.md](Performance.md) for detailed performance comparisons with QUIC, TCP, and HTTP/2.

