#!/usr/bin/env bash
# Standalone sqlite-cr launcher
# This script can be copied anywhere and will use nix to run sqlite-cr

set -euo pipefail

# The flake reference - update this to your GitHub repo
FLAKE_REF="${SQLITE_CR_FLAKE:-github:subtleGradient/sqlite-cr}"

# Run sqlite-cr using nix
exec nix run "$FLAKE_REF" -- "$@"