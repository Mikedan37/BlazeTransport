# Contributing to BlazeTransport

Thanks for your interest in contributing to BlazeTransport.

## Getting started

```bash
git clone https://github.com/Mikedan37/BlazeTransport.git
cd BlazeTransport
swift build
swift test
```

## Requirements

- Swift 5.9+
- macOS 14+ (for development)
- No external dependencies

## How to contribute

1. Fork the repository
2. Create a feature branch (`git checkout -b feature/my-change`)
3. Make your changes
4. Run `swift test` and ensure all tests pass
5. Submit a pull request

## What we're looking for

- Bug fixes with test cases
- Performance improvements with benchmark evidence
- Platform support (Linux, Windows)
- Documentation improvements
- Protocol specification feedback

## Code style

- Follow existing conventions in the codebase
- Use Swift's standard naming conventions
- Keep public API surface minimal
- Add tests for new functionality

## Reporting issues

Open an issue on GitHub with:
- What you expected to happen
- What actually happened
- Steps to reproduce
- Swift version and platform

## Project structure

```
Sources/BlazeTransport/          # Core library
Sources/BlazeTransportBenchmarks/ # Performance benchmarks
Sources/BlazeTransportFuzzing/   # Fuzz testing harness
Tests/BlazeTransportTests/       # Unit and integration tests
Examples/                        # Usage examples
Docs/                           # Architecture and design docs
c_decoder/                      # C reference decoder
```

## License

By contributing, you agree that your contributions will be licensed under the MIT License.
