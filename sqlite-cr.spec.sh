#!/usr/bin/env bash
# sqlite-cr.spec.sh - Legacy test runner
# For backwards compatibility - redirects to flake tests
echo "Running tests via nix flake..."
exec nix run .#tests "$@"