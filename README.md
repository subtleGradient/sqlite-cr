# sqlite-cr

SQLite with the cr-sqlite CRDT extension pre-loaded. Zero installation required!

✅ **Security verified** - Each platform binary has been cryptographically verified
✅ **Fully tested** - Comprehensive test suite with TDD methodology
✅ **Production ready** - Clean implementation following Kent Beck's principles

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

# Run tests (6 comprehensive tests following TDD)
./sqlite-cr.spec.sh

# Direct execution
sqlite-cr :memory: "SELECT 'development mode';"
```

## How It Works

This flake:
1. Downloads pre-built cr-sqlite binaries from official releases
2. Cryptographically verifies each platform binary with unique SHA256 hashes
3. Wraps SQLite with the extension pre-loaded
4. Provides a clean CLI interface
5. Works on macOS (arm64/x86_64) and Linux (x86_64)

## License

This wrapper is provided as-is. cr-sqlite is licensed under its own terms.
