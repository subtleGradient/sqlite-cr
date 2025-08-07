# sqlite-cr

SQLite with the cr-sqlite CRDT extension pre-loaded. Zero installation required!

✅ **Fully tested** - Comprehensive test suite with TDD methodology
✅ **Fast & streaming** - Direct output streaming, no buffering delays
✅ **Multi-platform** - macOS (arm64/x86_64) and Linux (x86_64/arm64)
✅ **Easy updates** - Simple version bump script included

## 🚀 Quick Start

Run directly from GitHub with a single command:

```bash
# Run sqlite-cr directly
nix run github:subtleGradient/sqlite-cr -- :memory: "SELECT crsql_site_id();"
```

That's it! No clone, no install, just run.

## Usage Examples

```bash
# Interactive session
nix run github:subtleGradient/sqlite-cr -- mydb.db

# Quick query
nix run github:subtleGradient/sqlite-cr -- :memory: "SELECT 1+1;"

# Create a CRDT-enabled table
nix run github:subtleGradient/sqlite-cr -- :memory: "
  CREATE TABLE items(id INTEGER PRIMARY KEY NOT NULL, name TEXT);
  SELECT crsql_as_crr('items');
  INSERT INTO items VALUES (1, 'Hello CRDT!');
  SELECT * FROM items;
"

# CSV output
nix run github:subtleGradient/sqlite-cr -- -csv :memory: "SELECT 'hello' as greeting, 42 as answer;"
```

## What is cr-sqlite?

[cr-sqlite](https://github.com/vlcn-io/cr-sqlite) adds CRDT (Conflict-free Replicated Data Type) support to SQLite, enabling:
- Multi-writer replication
- Automatic conflict resolution
- Offline-first applications
- Distributed SQLite databases

## Installation Options

While you can run directly with `nix run`, you can also install it:

### Install to User Profile
```bash
# From GitHub
nix profile install github:subtleGradient/sqlite-cr

# From local clone
nix profile install .

# Now use directly
sqlite-cr mydb.db
```

### Build Locally
```bash
git clone https://github.com/subtleGradient/sqlite-cr
cd sqlite-cr
nix build
./result/bin/sqlite-cr :memory: "SELECT crsql_site_id();"
```

### NixOS Configuration
```nix
{
  inputs.sqlite-cr.url = "github:subtleGradient/sqlite-cr";

  # In your system configuration
  environment.systemPackages = [
    inputs.sqlite-cr.packages.${system}.default
  ];
}
```

## Development

```bash
# Clone and enter dev shell
git clone https://github.com/subtleGradient/sqlite-cr
cd sqlite-cr
nix develop  # or use direnv

# Run tests
make test

# See all available tasks
make help

# Common development tasks
make build          # Build sqlite-cr
make test           # Run test suite  
make check          # Run flake checks
make dev            # Enter dev shell
make ci             # Simulate CI locally
```

## How It Works

This flake:
1. Downloads pre-built cr-sqlite binaries from official releases
2. Verifies downloads with Nix-provided SHA256 hashes
3. Wraps SQLite with the extension pre-loaded
4. Provides a clean CLI interface
5. Works on macOS (arm64/x86_64) and Linux (x86_64/arm64)
6. Streams output directly without buffering for better performance

## Updating cr-sqlite Version

To update to a new cr-sqlite version:
```bash
./update-version.sh 0.17.0  # Replace with desired version
```

This script automatically fetches new hashes and runs tests.

## CI/CD

This project includes comprehensive GitHub Actions workflows:

- **CI** - Builds and tests on all platforms (Linux/macOS × x86_64/ARM64)
- **Daily checks** - Monitors for outdated dependencies and placeholder hashes
- **Releases** - Automatically builds platform binaries for tagged releases

[![CI](https://github.com/subtleGradient/sqlite-cr/actions/workflows/ci.yml/badge.svg)](https://github.com/subtleGradient/sqlite-cr/actions/workflows/ci.yml)

## Platform Support

| Platform | Architecture | Status |
|----------|--------------|---------|
| macOS    | arm64 (Apple Silicon) | ✅ Verified |
| macOS    | x86_64 (Intel) | ✅ Verified |
| Linux    | x86_64 | ✅ Verified |
| Linux    | arm64/aarch64 | ✅ Verified |

## License

This project is licensed under the MIT License - see the [LICENSE](LICENSE) file for details.

### Components:
- **sqlite-cr wrapper**: MIT License (this project)
- **SQLite**: Public domain
- **cr-sqlite extension**: MIT License © 2023 One Law LLC
- **libcrsqlite binaries**: Redistributed under MIT License from [vlcn-io/cr-sqlite](https://github.com/vlcn-io/cr-sqlite)

Note: This project redistributes pre-built binaries from the cr-sqlite project. Please refer to the upstream project for their complete license terms.
