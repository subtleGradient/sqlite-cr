# Changelog

## Security Hardening Release (Unreleased)

### Security Improvements
- Added LICENSE file with proper attribution for cr-sqlite (MIT)
- Added SPDX headers to all source files
- Added SECURITY.md documenting supply chain approach
- Hardened wrapper to fail if multiple libraries found (prevent poisoned archives)
- Added TOFU warning and double-fetch verification in update script
- Improved sed precision to prevent multiple version replacements

### Bug Fixes
- Fixed potential shell injection in library path handling
- Documented harmless sqlite3_close() error instead of hiding it
- Fixed circular dependency in test runner
- Added proper timeout handling in CI

### Documentation
- Updated README with complete license information
- Added warning label to QEMU-emulated ARM64 Linux CI
- Created SECURITY.md with threat model documentation

### Known Limitations
- stderr filtering removed due to shell complexity - error now visible but documented
- No upstream GPG signatures available - using TOFU model
- ARM64 Linux testing runs under QEMU emulation

The time traveler's concerns have been addressed! 🚀