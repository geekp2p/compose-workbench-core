#!/bin/bash

# Build script for P2P Chat - Cross-platform binary builder
# Usage: ./build-release.sh [version]
# Example: ./build-release.sh 0.2.0

set -e

# Get version from argument or use current version
VERSION=${1:-$(grep 'var Version = ' internal/updater/updater.go | sed 's/.*"\(.*\)".*/\1/')}

echo "=========================================="
echo "Building P2P Chat v${VERSION}"
echo "=========================================="
echo ""

# Create output directory
DIST_DIR="../../dist"
mkdir -p "$DIST_DIR"

# Build flags for smaller binaries
LDFLAGS="-s -w"

# Array of platforms to build
declare -A PLATFORMS=(
    ["linux-amd64"]="linux amd64"
    ["linux-arm64"]="linux arm64"
    ["windows-amd64"]="windows amd64"
    ["windows-arm64"]="windows arm64"
    ["darwin-amd64"]="darwin amd64"
    ["darwin-arm64"]="darwin arm64"
)

echo "Building binaries for all platforms..."
echo ""

# Build for each platform
for platform in "${!PLATFORMS[@]}"; do
    read -r GOOS GOARCH <<< "${PLATFORMS[$platform]}"

    OUTPUT_NAME="p2p-chat-${platform}"

    # Add .exe extension for Windows
    if [ "$GOOS" = "windows" ]; then
        OUTPUT_NAME="${OUTPUT_NAME}.exe"
    fi

    OUTPUT_PATH="${DIST_DIR}/${OUTPUT_NAME}"

    echo "📦 Building ${OUTPUT_NAME}..."
    GOOS=$GOOS GOARCH=$GOARCH go build -ldflags="$LDFLAGS" -o "$OUTPUT_PATH"

    # Show file size
    if [ -f "$OUTPUT_PATH" ]; then
        SIZE=$(du -h "$OUTPUT_PATH" | cut -f1)
        echo "   ✓ Built successfully (${SIZE})"
    else
        echo "   ✗ Build failed!"
        exit 1
    fi
    echo ""
done

echo "=========================================="
echo "Generating checksums..."
echo "=========================================="
echo ""

cd "$DIST_DIR"
sha256sum p2p-chat-* > checksums.txt
echo "✓ Checksums saved to checksums.txt"
echo ""
cat checksums.txt
echo ""

echo "=========================================="
echo "Build Summary"
echo "=========================================="
echo "Version: ${VERSION}"
echo "Output directory: ${DIST_DIR}"
echo ""
ls -lh "$DIST_DIR"
echo ""

echo "=========================================="
echo "✓ Build complete!"
echo "=========================================="
echo ""
echo "Next steps:"
echo "  1. Test the binaries"
echo "  2. Create a git tag: git tag p2p-chat-v${VERSION}"
echo "  3. Push the tag: git push origin p2p-chat-v${VERSION}"
echo "  4. GitHub Actions will automatically create the release"
echo ""
