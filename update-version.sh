#!/usr/bin/env bash
set -euo pipefail

# update-version.sh
# Script to update cr-sqlite version and regenerate hashes
# Makes version bumps painless and ensures green commits

if [ $# -ne 1 ]; then
    echo "Usage: $0 <new-version>"
    echo "Example: $0 0.17.0"
    exit 1
fi

NEW_VERSION="$1"
echo "Updating to cr-sqlite v$NEW_VERSION..."

# Update version in flake.nix
sed -i.bak "s/version = \".*\";/version = \"$NEW_VERSION\";/" flake.nix

# Fetch new hashes
echo "Fetching new hashes..."

PLATFORMS=(
    "aarch64-darwin"
    "x86_64-darwin"
    "x86_64-linux"
    "aarch64-linux"
)

for platform in "${PLATFORMS[@]}"; do
    echo "Fetching hash for $platform..."
    
    # Determine platform parts
    case $platform in
        *-darwin) os="darwin" ;;
        *-linux) os="linux" ;;
    esac
    
    case $platform in
        aarch64-*) arch="aarch64" ;;
        x86_64-*) arch="x86_64" ;;
    esac
    
    url="https://github.com/vlcn-io/cr-sqlite/releases/download/v${NEW_VERSION}/crsqlite-${os}-${arch}.zip"
    
    # Fetch hash
    hash=$(nix-prefetch-url "$url" --unpack 2>/dev/null || echo "FAILED")
    
    if [ "$hash" = "FAILED" ]; then
        echo "Warning: Failed to fetch $platform binary"
        continue
    fi
    
    # Update hash in flake.nix
    sed -i.bak "s/\"$platform\" = \"sha256-.*\";/\"$platform\" = \"sha256-$hash\";/" flake.nix
done

# Clean up backup files
rm -f flake.nix.bak

echo "Version update complete! Running tests..."
./sqlite-cr.spec.sh

echo
echo "✅ Version bumped to $NEW_VERSION"
echo "Please review changes and commit:"
echo "  git diff flake.nix"
echo "  git commit -m 'Update cr-sqlite to v$NEW_VERSION'"