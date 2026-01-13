# P2P Chat Release Guide 🚀

Complete guide for building and releasing P2P Chat binaries.

**✨ NEW:** Full Windows support with PowerShell scripts! See [Local Build](#local-build) for details.

---

## 📋 Table of Contents

- [Quick Start](#quick-start)
- [Release Workflow](#release-workflow)
- [Local Build](#local-build)
- [GitHub Actions Release](#github-actions-release)
- [Version Management](#version-management)
- [Troubleshooting](#troubleshooting)
  - [Windows-Specific Issues](#windows-specific-issues)
- [Advanced Topics](#advanced-topics)

---

## 🪟 Windows Users

If you're on Windows 11 (or Windows 10), you have **three options** to build releases:

1. **Easiest:** Use `build-release.cmd` (works everywhere)
   ```cmd
   cd projects\p2p-chat-go
   build-release.cmd
   ```

2. **PowerShell:** Use `build-release.ps1` directly
   ```powershell
   cd projects\p2p-chat-go
   .\build-release.ps1
   ```

3. **WSL/Git Bash:** Use the Linux shell script
   ```bash
   cd projects/p2p-chat-go
   ./build-release.sh
   ```

**All three methods produce identical binaries for all 6 platforms!**

---

## 🚀 Quick Start

### Create a New Release (Automated via GitHub Actions)

#### On Linux / macOS / WSL

```bash
# 1. Update version in code
cd projects/p2p-chat-go
vi internal/updater/updater.go
# Change: var Version = "0.2.0"

# 2. Commit changes
git add internal/updater/updater.go
git commit -m "chore: bump version to 0.2.0"
git push

# 3. Create and push tag (must start with p2p-chat-v)
git tag p2p-chat-v0.2.0
git push origin p2p-chat-v0.2.0

# 4. Done! GitHub Actions will automatically:
#    - Build binaries for 6 platforms
#    - Generate checksums
#    - Create GitHub release
#    - Upload all binaries
```

#### On Windows

```powershell
# 1. Update version in code
cd projects\p2p-chat-go
notepad internal\updater\updater.go
# Change: var Version = "0.2.0"

# 2. Commit changes
git add internal\updater\updater.go
git commit -m "chore: bump version to 0.2.0"
git push

# 3. Create and push tag (must start with p2p-chat-v)
git tag p2p-chat-v0.2.0
git push origin p2p-chat-v0.2.0

# 4. Done! GitHub Actions will automatically:
#    - Build binaries for 6 platforms
#    - Generate checksums
#    - Create GitHub release
#    - Upload all binaries
```

⏱️ **Build time:** ~3-5 minutes

---

## 🔄 Release Workflow

### Overview

```mermaid
graph LR
    A[Update Version] --> B[Commit & Push]
    B --> C[Create Tag]
    C --> D[Push Tag]
    D --> E[GitHub Actions]
    E --> F[Build Binaries]
    F --> G[Create Release]
    G --> H[Upload Assets]
```

### Step-by-Step Process

#### 1️⃣ Update Version Number

Edit `internal/updater/updater.go`:

```go
// Before
var Version = "0.1.0"

// After
var Version = "0.2.0"
```

#### 2️⃣ Commit Changes

```bash
cd projects/p2p-chat-go
git add internal/updater/updater.go
git commit -m "chore: bump version to 0.2.0"
git push
```

#### 3️⃣ Create Git Tag

**IMPORTANT:** Tag MUST start with `p2p-chat-v`

```bash
# ✅ Correct format
git tag p2p-chat-v0.2.0
git tag p2p-chat-v1.0.0
git tag p2p-chat-v1.2.3-beta

# ❌ Wrong format (won't trigger release)
git tag v0.2.0
git tag 0.2.0
git tag release-0.2.0
```

#### 4️⃣ Push Tag to GitHub

```bash
git push origin p2p-chat-v0.2.0
```

#### 5️⃣ Monitor Build

1. Go to: https://github.com/geekp2p/compose-workbench-core/actions
2. Click on the running workflow
3. Wait for completion (~3-5 minutes)
4. Check for errors in build logs

#### 6️⃣ Verify Release

1. Go to: https://github.com/geekp2p/compose-workbench-core/releases
2. Find your new release
3. Verify all 7 files are uploaded:
   - `p2p-chat-linux-amd64`
   - `p2p-chat-linux-arm64`
   - `p2p-chat-windows-amd64.exe`
   - `p2p-chat-windows-arm64.exe`
   - `p2p-chat-darwin-amd64`
   - `p2p-chat-darwin-arm64`
   - `checksums.txt`

---

## 📤 Manual Release Upload

If you prefer to upload releases manually instead of using GitHub Actions:

### Prerequisites

1. **Install GitHub CLI:**
   - Windows: `winget install GitHub.cli` or `choco install gh`
   - macOS: `brew install gh`
   - Linux: `sudo apt install gh`

2. **Authenticate:**
   ```bash
   gh auth login
   ```

### Upload Release

#### On Windows

```cmd
REM Upload with auto-detected version
upload-release.cmd

REM Test without uploading (dry run)
upload-release.ps1 -DryRun
```

#### On Linux/macOS

```bash
# Upload with auto-detected version
./upload-release.sh

# Test without uploading (dry run)
./upload-release.sh --dry-run
```

### What the Upload Script Does

1. ✅ Reads version from `internal/updater/updater.go`
2. ✅ Creates git tag (e.g., `p2p-chat-v0.1.0`)
3. ✅ Pushes tag to GitHub
4. ✅ Creates GitHub release with description
5. ✅ Uploads all binaries from `dist/` directory
6. ✅ Uploads checksums.txt
7. ✅ Provides release URL

### Example Output

```
+===================================================+
|     P2P Chat GitHub Release Uploader             |
+===================================================+

Using version from updater.go: 0.1.0

[OK] GitHub CLI is installed
[OK] Authenticated with GitHub

Found 6 binaries to upload:
  - p2p-chat-darwin-amd64 (30.84 MB)
  - p2p-chat-darwin-arm64 (29.45 MB)
  - p2p-chat-linux-amd64 (29.32 MB)
  - p2p-chat-linux-arm64 (27.75 MB)
  - p2p-chat-windows-amd64.exe (30.01 MB)
  - p2p-chat-windows-arm64.exe (28.05 MB)

[OK] Checksums file found

Creating tag p2p-chat-v0.1.0...
[OK] Tag created: p2p-chat-v0.1.0

Pushing tag to remote...
[OK] Tag pushed to remote

Creating GitHub release...
[OK] GitHub release created

Uploading binaries to release...
[OK] Uploaded: p2p-chat-darwin-amd64
[OK] Uploaded: p2p-chat-darwin-arm64
[OK] Uploaded: p2p-chat-linux-amd64
[OK] Uploaded: p2p-chat-linux-arm64
[OK] Uploaded: p2p-chat-windows-amd64.exe
[OK] Uploaded: p2p-chat-windows-arm64.exe
[OK] Uploaded: checksums.txt

+===================================================+
|              Upload Summary                       |
+===================================================+
Version:     0.1.0
Tag:         p2p-chat-v0.1.0
Uploaded:    7 files

[OK] Release upload completed!

View release at:
  https://github.com/geekp2p/compose-workbench-core/releases/tag/p2p-chat-v0.1.0
```

---

## 🔨 Local Build

### Build All Platforms

#### On Linux / macOS / WSL

```bash
cd projects/p2p-chat-go

# Build with specific version
./build-release.sh 0.2.0

# Or use version from updater.go
./build-release.sh
```

#### On Windows

**Option 1: Using Command Prompt / CMD**

```cmd
cd projects\p2p-chat-go

REM Build with specific version
build-release.cmd 0.2.0

REM Or use version from updater.go
build-release.cmd
```

**Option 2: Using PowerShell**

```powershell
cd projects\p2p-chat-go

# Build with specific version
.\build-release.ps1 -Version "0.2.0"

# Or use version from updater.go
.\build-release.ps1
```

**Note:** The Windows scripts (`build-release.cmd` and `build-release.ps1`) work on both PowerShell 5.1 (Windows PowerShell) and PowerShell 7+ (PowerShell Core).

### Output

Binaries will be created in `../../dist/`:

```
compose-workbench-core/
└── dist/
    ├── p2p-chat-linux-amd64       (~18 MB)
    ├── p2p-chat-linux-arm64       (~17 MB)
    ├── p2p-chat-windows-amd64.exe (~20 MB)
    ├── p2p-chat-windows-arm64.exe (~19 MB)
    ├── p2p-chat-darwin-amd64      (~19 MB)
    ├── p2p-chat-darwin-arm64      (~18 MB)
    └── checksums.txt
```

### Test Binaries Locally

```bash
# Linux
../../dist/p2p-chat-linux-amd64

# Windows (from WSL)
../../dist/p2p-chat-windows-amd64.exe

# macOS
../../dist/p2p-chat-darwin-amd64
```

### Build for Single Platform

#### On Linux / macOS / WSL

```bash
# Linux AMD64
GOOS=linux GOARCH=amd64 go build -o p2p-chat-linux .

# Windows AMD64
GOOS=windows GOARCH=amd64 go build -o p2p-chat-windows.exe .

# macOS ARM64 (Apple Silicon)
GOOS=darwin GOARCH=arm64 go build -o p2p-chat-macos .
```

#### On Windows PowerShell

```powershell
# Linux AMD64
$env:GOOS="linux"; $env:GOARCH="amd64"; go build -o p2p-chat-linux .

# Windows AMD64
$env:GOOS="windows"; $env:GOARCH="amd64"; go build -o p2p-chat-windows.exe .

# macOS ARM64 (Apple Silicon)
$env:GOOS="darwin"; $env:GOARCH="arm64"; go build -o p2p-chat-macos .
```

#### On Windows CMD

```cmd
REM Linux AMD64
set GOOS=linux
set GOARCH=amd64
go build -o p2p-chat-linux .

REM Windows AMD64
set GOOS=windows
set GOARCH=amd64
go build -o p2p-chat-windows.exe .

REM macOS ARM64 (Apple Silicon)
set GOOS=darwin
set GOARCH=arm64
go build -o p2p-chat-macos .
```

---

## ⚙️ GitHub Actions Release

### Workflow File

Located at: `.github/workflows/release-p2p-chat.yml`

### Trigger

Automatically runs when you push a tag starting with `p2p-chat-v`:

```yaml
on:
  push:
    tags:
      - 'p2p-chat-v*'
```

### Build Matrix

The workflow builds for 6 platforms:

| Platform | OS | Architecture | Output |
|----------|----|--------------| -------|
| Linux | linux | amd64 | `p2p-chat-linux-amd64` |
| Linux | linux | arm64 | `p2p-chat-linux-arm64` |
| Windows | windows | amd64 | `p2p-chat-windows-amd64.exe` |
| Windows | windows | arm64 | `p2p-chat-windows-arm64.exe` |
| macOS | darwin | amd64 | `p2p-chat-darwin-amd64` |
| macOS | darwin | arm64 | `p2p-chat-darwin-arm64` |

### Build Flags

Binaries are built with:

```bash
CGO_ENABLED=0 go build \
  -ldflags="-s -w -X github.com/geekp2p/p2p-chat-go/internal/updater.Version=${VERSION}" \
  -o p2p-chat .
```

**Flags explained:**
- `CGO_ENABLED=0` - Static binary (no C dependencies)
- `-s -w` - Strip debug info (smaller binary)
- `-X` - Inject version at build time

### GitHub Token

The workflow uses `GITHUB_TOKEN` which is automatically provided by GitHub Actions. No manual setup needed.

---

## 📦 Version Management

### Semantic Versioning

Follow [SemVer 2.0.0](https://semver.org/):

```
MAJOR.MINOR.PATCH

Example: 1.2.3
         │ │ │
         │ │ └─ Bug fixes (backward compatible)
         │ └─── New features (backward compatible)
         └───── Breaking changes
```

**Examples:**

```bash
# Bug fix
0.1.0 → 0.1.1

# New feature
0.1.1 → 0.2.0

# Breaking change
0.2.0 → 1.0.0

# Pre-release
1.0.0-alpha
1.0.0-beta.1
1.0.0-rc.1
```

### Version Update Checklist

Before releasing a new version:

- [ ] Update `internal/updater/updater.go`
- [ ] Test build locally (`./build-release.sh`)
- [ ] Update `README.md` if needed (new features)
- [ ] Update `CHANGELOG.md` (if you maintain one)
- [ ] Commit all changes
- [ ] Create and push tag

### Where Version is Used

1. **`internal/updater/updater.go`** - Source of truth
   ```go
   var Version = "0.2.0"
   ```

2. **Build script** - Injected at compile time
   ```bash
   -ldflags="-X .../internal/updater.Version=${VERSION}"
   ```

3. **GitHub Release** - Extracted from tag
   ```bash
   p2p-chat-v0.2.0 → Version: 0.2.0
   ```

4. **Binary** - Check version:
   ```bash
   ./p2p-chat-linux-amd64 --version
   # Output: p2p-chat v0.2.0 (linux/amd64)
   ```

---

## 🐛 Troubleshooting

### Build Fails on GitHub Actions

**Problem:** Workflow fails with build errors

**Solutions:**

1. **Check Go version mismatch**
   ```yaml
   # In .github/workflows/release-p2p-chat.yml
   - name: Set up Go
     uses: actions/setup-go@v5
     with:
       go-version: '1.21'  # Must match go.mod version
   ```

2. **Verify go.mod**
   ```bash
   cd projects/p2p-chat-go
   go mod tidy
   go mod verify
   ```

3. **Test build locally first**
   ```bash
   ./build-release.sh
   ```

### Tag Doesn't Trigger Workflow

**Problem:** Pushed tag but no workflow runs

**Solutions:**

1. **Check tag format**
   ```bash
   # Must start with p2p-chat-v
   git tag -l "p2p-chat-v*"

   # Delete wrong tag
   git tag -d v0.2.0
   git push origin :refs/tags/v0.2.0

   # Create correct tag
   git tag p2p-chat-v0.2.0
   git push origin p2p-chat-v0.2.0
   ```

2. **Verify workflow file exists**
   ```bash
   ls .github/workflows/release-p2p-chat.yml
   ```

3. **Check GitHub Actions is enabled**
   - Go to: Settings → Actions → General
   - Ensure "Allow all actions" is selected

### Release Creation Fails

**Problem:** Binaries build but release isn't created

**Solutions:**

1. **Check repository permissions**
   ```yaml
   # In workflow file
   permissions:
     contents: write  # Required for creating releases
   ```

2. **Verify GITHUB_TOKEN has permissions**
   - Go to: Settings → Actions → General → Workflow permissions
   - Select "Read and write permissions"

3. **Check for duplicate release**
   ```bash
   # Delete existing release if needed (via GitHub UI)
   # Then re-run workflow
   ```

### Binary Size Too Large

**Problem:** Binaries are larger than expected

**Solutions:**

1. **Ensure build flags are used**
   ```bash
   -ldflags="-s -w"  # Strip debug symbols
   ```

2. **Use UPX compression (optional)**
   ```bash
   upx --best --lzma p2p-chat-linux-amd64
   ```

3. **Check for embedded files**
   ```bash
   # List binary sections
   go tool nm p2p-chat-linux-amd64 | wc -l
   ```

### Cross-Compilation Fails

**Problem:** Can't build for certain platforms

**Solutions:**

1. **Install cross-compile tools**
   ```bash
   # Linux
   sudo apt-get install gcc-multilib

   # macOS
   brew install mingw-w64
   ```

2. **Use CGO_ENABLED=0**
   ```bash
   CGO_ENABLED=0 GOOS=windows GOARCH=amd64 go build
   ```

3. **Check Go supports the platform**
   ```bash
   go tool dist list | grep -E "linux|windows|darwin"
   ```

### Windows-Specific Issues

**Problem:** PowerShell script execution is disabled

**Error:** `build-release.ps1 cannot be loaded because running scripts is disabled on this system`

**Solutions:**

1. **Temporary bypass (recommended for testing)**
   ```powershell
   PowerShell -ExecutionPolicy Bypass -File .\build-release.ps1
   ```

2. **Use the CMD wrapper (easiest)**
   ```cmd
   build-release.cmd
   ```

3. **Change execution policy for current user**
   ```powershell
   Set-ExecutionPolicy -ExecutionPolicy RemoteSigned -Scope CurrentUser
   .\build-release.ps1
   ```

**Problem:** Can't find `pwsh` or `powershell` command

**Solutions:**

1. **Check if PowerShell is in PATH**
   ```cmd
   where powershell
   where pwsh
   ```

2. **Use full path**
   ```cmd
   C:\Windows\System32\WindowsPowerShell\v1.0\powershell.exe -File build-release.ps1
   ```

3. **Install PowerShell 7+** (recommended)
   - Download from: https://github.com/PowerShell/PowerShell/releases
   - Or use winget: `winget install Microsoft.PowerShell`

**Problem:** Build fails with "Access denied" or permission errors

**Solutions:**

1. **Run as Administrator**
   - Right-click PowerShell → "Run as administrator"
   - Navigate to project folder and run script

2. **Check antivirus**
   - Temporarily disable antivirus
   - Add exception for Go build tools

3. **Use different output directory**
   ```powershell
   # Edit build-release.ps1 to use different path
   $DIST_DIR = "C:\temp\dist"
   ```

---

## 🔬 Advanced Topics

### Custom Build Flags

Add custom flags to `build-release.sh`:

```bash
# Add build date
BUILD_DATE=$(date -u +"%Y-%m-%dT%H:%M:%SZ")
LDFLAGS="-s -w -X ${GO_MODULE}/internal/updater.Version=${VERSION} -X ${GO_MODULE}/internal/updater.BuildDate=${BUILD_DATE}"
```

### Pre-release Tags

Create pre-release versions:

```bash
# Alpha
git tag p2p-chat-v0.3.0-alpha
git push origin p2p-chat-v0.3.0-alpha

# Beta
git tag p2p-chat-v0.3.0-beta.1
git push origin p2p-chat-v0.3.0-beta.1

# Release Candidate
git tag p2p-chat-v1.0.0-rc.1
git push origin p2p-chat-v1.0.0-rc.1
```

Mark as pre-release in GitHub:

```yaml
# In workflow file
- name: Create GitHub Release
  uses: softprops/action-gh-release@v1
  with:
    prerelease: ${{ contains(github.ref, 'alpha') || contains(github.ref, 'beta') || contains(github.ref, 'rc') }}
```

### Code Signing (macOS)

Sign binaries for macOS:

```bash
# Sign binary
codesign --sign "Developer ID Application" p2p-chat-darwin-amd64

# Verify signature
codesign --verify --verbose p2p-chat-darwin-amd64

# Create notarized DMG
hdiutil create -volname "P2P Chat" -srcfolder . -ov -format UDZO p2p-chat.dmg
```

### Docker Images

Build and push Docker images:

```bash
# Build multi-arch image
docker buildx build \
  --platform linux/amd64,linux/arm64 \
  -t geekp2p/p2p-chat:0.2.0 \
  -t geekp2p/p2p-chat:latest \
  --push \
  .
```

### Automated Version Bumping

Use a script to bump version:

```bash
#!/bin/bash
# bump-version.sh

CURRENT_VERSION=$(grep 'var Version = ' internal/updater/updater.go | sed 's/.*"\(.*\)".*/\1/')
echo "Current version: $CURRENT_VERSION"

# Parse version
IFS='.' read -r MAJOR MINOR PATCH <<< "$CURRENT_VERSION"

# Bump based on argument
case "$1" in
  major)
    NEW_VERSION="$((MAJOR + 1)).0.0"
    ;;
  minor)
    NEW_VERSION="${MAJOR}.$((MINOR + 1)).0"
    ;;
  patch)
    NEW_VERSION="${MAJOR}.${MINOR}.$((PATCH + 1))"
    ;;
  *)
    echo "Usage: $0 {major|minor|patch}"
    exit 1
    ;;
esac

echo "New version: $NEW_VERSION"

# Update file
sed -i "s/var Version = \"$CURRENT_VERSION\"/var Version = \"$NEW_VERSION\"/" internal/updater/updater.go

# Commit and tag
git add internal/updater/updater.go
git commit -m "chore: bump version to $NEW_VERSION"
git tag "p2p-chat-v$NEW_VERSION"

echo "Done! Push with: git push && git push origin p2p-chat-v$NEW_VERSION"
```

---

## 📚 References

- **GitHub Actions Documentation**: https://docs.github.com/en/actions
- **Go Cross Compilation**: https://go.dev/wiki/GoArm
- **Semantic Versioning**: https://semver.org/
- **goreleaser** (alternative tool): https://goreleaser.com/

---

## 📝 Changelog Template

Maintain a `CHANGELOG.md`:

```markdown
# Changelog

## [0.2.0] - 2024-01-15

### Added
- Auto-update check on startup
- Version command (`--version`)

### Changed
- Improved peer discovery speed
- Updated libp2p to v0.30.0

### Fixed
- Message duplication bug
- Memory leak in DHT

## [0.1.0] - 2024-01-01

### Added
- Initial release
- P2P chat functionality
- GossipSub messaging
```

---

**Happy Releasing! 🎉**
