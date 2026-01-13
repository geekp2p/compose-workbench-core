# Release Guide for P2P Chat

This document describes how to create a new release of P2P Chat.

## Supported Platforms

The build process automatically creates binaries for:

- **Linux**
  - AMD64 (x86_64) - Standard Intel/AMD processors
  - ARM64 (aarch64) - ARM processors (Raspberry Pi 4+, AWS Graviton, etc.)

- **Windows**
  - AMD64 (x86_64) - Standard Intel/AMD processors
  - ARM64 - ARM processors (Windows on ARM devices)

- **macOS**
  - AMD64 - Intel Macs
  - ARM64 - Apple Silicon (M1, M2, M3, etc.)

## Quick Release Process

### 1. Update Version

Edit `internal/updater/updater.go`:

```go
var Version = "0.2.0"  // Update this line
```

### 2. Commit Changes

```bash
git add .
git commit -m "chore: bump version to 0.2.0"
git push
```

### 3. Create and Push Tag

```bash
# Create tag with 'p2p-chat-v' prefix
git tag p2p-chat-v0.2.0

# Push tag to trigger GitHub Actions
git push origin p2p-chat-v0.2.0
```

### 4. Wait for GitHub Actions

GitHub Actions will automatically:
- ✅ Build binaries for all 6 platforms
- ✅ Generate SHA256 checksums
- ✅ Create GitHub Release
- ✅ Upload all binaries
- ✅ Generate release notes

### 5. Verify Release

1. Go to: https://github.com/geekp2p/compose-workbench-core/releases
2. Check that all 6 binaries are present:
   - `p2p-chat-linux-amd64`
   - `p2p-chat-linux-arm64`
   - `p2p-chat-windows-amd64.exe`
   - `p2p-chat-windows-arm64.exe`
   - `p2p-chat-darwin-amd64`
   - `p2p-chat-darwin-arm64`
   - `checksums.txt`

### 6. Test Auto-Update

```bash
# Run old version
./p2p-chat

# It should show update notification:
# 🎉 New version available: p2p-chat-v0.2.0 (current: 0.1.0)
# Run /update command to upgrade automatically

# Test update
> /update
```

## Local Testing (Optional)

Before creating a release, you can build and test locally:

```bash
cd projects/p2p-chat-go

# Make build script executable
chmod +x build-release.sh

# Build all binaries
./build-release.sh 0.2.0

# Binaries will be in ../../dist/
ls -lh ../../dist/
```

## Manual Release (Without GitHub Actions)

If you need to create a release manually:

### 1. Build Binaries

```bash
cd projects/p2p-chat-go

# Build all platforms
./build-release.sh 0.2.0
```

### 2. Create Release on GitHub

1. Go to: https://github.com/geekp2p/compose-workbench-core/releases/new
2. Create tag: `p2p-chat-v0.2.0`
3. Release title: `P2P Chat 0.2.0`
4. Upload all files from `dist/` folder
5. Publish release

## Version Naming Convention

- Use semantic versioning: `MAJOR.MINOR.PATCH`
- Examples:
  - `0.1.0` - Initial release
  - `0.2.0` - New features added
  - `0.2.1` - Bug fixes
  - `1.0.0` - First stable release

## Tag Naming Convention

- Always prefix with `p2p-chat-v`
- Examples:
  - `p2p-chat-v0.1.0`
  - `p2p-chat-v0.2.0`
  - `p2p-chat-v1.0.0`

This prefix ensures the workflow only triggers for P2P Chat releases, not other projects in the monorepo.

## Troubleshooting

### Build Fails on GitHub Actions

1. Check the Actions tab: https://github.com/geekp2p/compose-workbench-core/actions
2. Click on the failed workflow
3. Check the logs for errors

Common issues:
- **Go module errors**: Make sure `go.mod` is up to date
- **Build errors**: Test locally with `./build-release.sh` first
- **Permission errors**: Check repository settings → Actions → General → Workflow permissions

### Update Not Working

1. Check binary naming matches exactly:
   - Format: `p2p-chat-{os}-{arch}[.exe]`
   - Examples: `p2p-chat-linux-amd64`, `p2p-chat-windows-arm64.exe`

2. Verify checksums are correct:
   - Download `checksums.txt` from release
   - Verify each binary with: `sha256sum -c checksums.txt`

3. Check GitHub API rate limits:
   - Anonymous requests: 60/hour
   - Authenticated: 5000/hour

## Release Checklist

Before creating a release:

- [ ] Update version in `internal/updater/updater.go`
- [ ] Test build locally with `./build-release.sh`
- [ ] Commit and push changes
- [ ] Create and push tag: `git tag p2p-chat-v0.X.0 && git push origin p2p-chat-v0.X.0`
- [ ] Wait for GitHub Actions to complete
- [ ] Verify all 6 binaries + checksums are uploaded
- [ ] Test auto-update from old version
- [ ] Update release notes if needed

## Binary Size Optimization

The build script uses these flags for smaller binaries:

```bash
-ldflags="-s -w"
```

- `-s` - Omit symbol table and debug info
- `-w` - Omit DWARF symbol table

Typical binary sizes:
- Linux/macOS: ~15-20 MB
- Windows: ~16-22 MB

## Security

- All binaries are built on GitHub's secure runners
- SHA256 checksums are generated for verification
- Users can verify downloads: `sha256sum -c checksums.txt`
- Auto-update verifies signatures before replacing binaries

## Questions?

- Check GitHub Actions logs: https://github.com/geekp2p/compose-workbench-core/actions
- Review this guide: `projects/p2p-chat-go/RELEASE.md`
- Test locally first: `./build-release.sh`
