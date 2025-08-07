# Security Policy

## Supply Chain Security

This project redistributes pre-built binaries from the cr-sqlite project. We implement several security measures:

### Hash Verification
- All binaries are verified against cryptographic SHA256 hashes stored in `hashes.nix`
- Hashes are computed on first download (TOFU - Trust On First Use)
- Any tampering after initial hash computation will be detected by Nix

### Known Limitations
1. **No upstream signatures**: The cr-sqlite project does not provide GPG signatures for releases
2. **TOFU model**: Initial hash computation trusts the first download
3. **Binary distribution**: We redistribute binaries rather than building from source

### Recommendations
- Verify releases at https://github.com/vlcn-io/cr-sqlite/releases before updating
- Review hash changes in git history
- Consider building from source if your threat model requires it

## Reporting Security Issues

Please report security issues to [create an issue](https://github.com/subtleGradient/sqlite-cr/issues) with the "security" label.