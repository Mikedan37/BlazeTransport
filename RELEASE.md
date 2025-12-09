# BlazeTransport Release Checklist

Use this checklist when preparing a new release of BlazeTransport.

## Pre-Release

- [ ] Update version in `Package.swift` (if needed)
- [ ] Update `CHANGELOG.md` with release notes
- [ ] Review and update `README.md` overview and examples
- [ ] Ensure all documentation is up to date
- [ ] Review `SECURITY.md` for any security-related changes

## Testing

- [ ] Run full test suite: `swift test`
- [ ] Run benchmarks: `swift run BlazeTransportBenchmarks --all`
- [ ] Verify examples compile and run: `swift build --target EchoServer` and `swift build --target EchoClient`
- [ ] Test with thread sanitizer: `swift build --sanitize=thread`
- [ ] Test with address sanitizer: `swift build --sanitize=address` (if available)

## Code Quality

- [ ] Run SwiftFormat (if configured): `swiftformat .`
- [ ] Run SwiftLint (if configured): `swiftlint lint`
- [ ] Fix all warnings
- [ ] Ensure no dead code or unused imports
- [ ] Review public API for stability

## Documentation

- [ ] Verify README is clean and up to date
- [ ] Check all Docs/ files are accurate
- [ ] Verify examples work correctly
- [ ] Update API documentation if needed

## Release

- [ ] Commit all changes with clear commit message
- [ ] Create git tag: `git tag -a v0.1.0 -m "Release v0.1.0"`
- [ ] Push commits: `git push origin main`
- [ ] Push tags: `git push origin v0.1.0`
- [ ] Create GitHub release with release notes from CHANGELOG.md

## Post-Release

- [ ] Verify GitHub release was created successfully
- [ ] Test installation from GitHub: `swift package add https://github.com/Mikedan37/BlazeTransport.git`
- [ ] Monitor for any issues or bug reports
- [ ] Update roadmap if needed

## Version History

- **v0.1.0**: Initial production release
  - Complete transport protocol implementation
  - Multi-stream support
  - Security hardening
  - Comprehensive documentation
  - Full test coverage

