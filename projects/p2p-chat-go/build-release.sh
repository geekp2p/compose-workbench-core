#!/bin/bash
set -e

# P2P Chat Multi-Platform Build Script
# Builds binaries for Linux, Windows, and macOS (amd64 & arm64)

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Configuration
APP_NAME="p2p-chat"
DIST_DIR="../../dist"
GO_MODULE="github.com/geekp2p/p2p-chat-go"

# Platforms to build
PLATFORMS=(
    "linux/amd64"
    "linux/arm64"
    "windows/amd64"
    "windows/arm64"
    "darwin/amd64"
    "darwin/arm64"
)

# Get version from argument or use default from updater.go
VERSION="${1:-}"
if [ -z "$VERSION" ]; then
    # Extract version from internal/updater/updater.go
    VERSION=$(grep 'var Version = ' internal/updater/updater.go | sed 's/.*"\(.*\)".*/\1/' || echo "0.1.0")
    echo -e "${YELLOW}No version specified, using version from updater.go: ${VERSION}${NC}"
else
    echo -e "${GREEN}Building version: ${VERSION}${NC}"
fi

# Print banner
echo -e "${BLUE}"
echo "╔═══════════════════════════════════════════════════╗"
echo "║     P2P Chat Multi-Platform Build System         ║"
echo "║     Building v${VERSION}                              ║"
echo "╚═══════════════════════════════════════════════════╝"
echo -e "${NC}"

# Check if Go is installed
if ! command -v go &> /dev/null; then
    echo -e "${RED}Error: Go is not installed${NC}"
    exit 1
fi

echo -e "${GREEN}✓ Go version: $(go version)${NC}\n"

# Create dist directory
echo -e "${BLUE}Creating distribution directory...${NC}"
rm -rf "$DIST_DIR"
mkdir -p "$DIST_DIR"
echo -e "${GREEN}✓ Created: ${DIST_DIR}${NC}\n"

# Build for each platform
echo -e "${BLUE}Building binaries for ${#PLATFORMS[@]} platforms...${NC}\n"

for PLATFORM in "${PLATFORMS[@]}"; do
    # Split platform into OS and ARCH
    IFS="/" read -r GOOS GOARCH <<< "$PLATFORM"

    # Determine output filename
    OUTPUT_NAME="${APP_NAME}-${GOOS}-${GOARCH}"
    if [ "$GOOS" = "windows" ]; then
        OUTPUT_NAME="${OUTPUT_NAME}.exe"
    fi

    OUTPUT_PATH="${DIST_DIR}/${OUTPUT_NAME}"

    # Build
    echo -e "${YELLOW}Building ${GOOS}/${GOARCH}...${NC}"

    # Set build flags
    LDFLAGS="-s -w -X ${GO_MODULE}/internal/updater.Version=${VERSION}"

    env GOOS="$GOOS" GOARCH="$GOARCH" CGO_ENABLED=0 \
        go build \
        -ldflags="$LDFLAGS" \
        -o "$OUTPUT_PATH" \
        .

    # Check if build succeeded
    if [ $? -eq 0 ]; then
        SIZE=$(ls -lh "$OUTPUT_PATH" | awk '{print $5}')
        echo -e "${GREEN}✓ Built: ${OUTPUT_NAME} (${SIZE})${NC}\n"
    else
        echo -e "${RED}✗ Failed to build ${OUTPUT_NAME}${NC}\n"
        exit 1
    fi
done

# Generate checksums
echo -e "${BLUE}Generating SHA256 checksums...${NC}"
cd "$DIST_DIR"

# Create checksums file
CHECKSUM_FILE="checksums.txt"
rm -f "$CHECKSUM_FILE"

for FILE in p2p-chat-*; do
    if [ -f "$FILE" ]; then
        if command -v sha256sum &> /dev/null; then
            sha256sum "$FILE" >> "$CHECKSUM_FILE"
        elif command -v shasum &> /dev/null; then
            shasum -a 256 "$FILE" >> "$CHECKSUM_FILE"
        else
            echo -e "${YELLOW}Warning: No SHA256 tool found${NC}"
            break
        fi
    fi
done

if [ -f "$CHECKSUM_FILE" ]; then
    echo -e "${GREEN}✓ Checksums generated: ${CHECKSUM_FILE}${NC}\n"
fi

cd - > /dev/null

# Summary
echo -e "${BLUE}╔═══════════════════════════════════════════════════╗${NC}"
echo -e "${BLUE}║              Build Summary                        ║${NC}"
echo -e "${BLUE}╚═══════════════════════════════════════════════════╝${NC}"
echo -e "${GREEN}Version:${NC}     ${VERSION}"
echo -e "${GREEN}Directory:${NC}   ${DIST_DIR}"
echo -e "${GREEN}Binaries:${NC}    ${#PLATFORMS[@]} platforms"
echo ""
echo -e "${YELLOW}Binaries created:${NC}"
ls -lh "$DIST_DIR"

echo ""
echo -e "${GREEN}✓ Build completed successfully!${NC}"
echo ""
echo -e "${BLUE}To test binaries:${NC}"
echo -e "  Linux:   ${DIST_DIR}/p2p-chat-linux-amd64"
echo -e "  Windows: ${DIST_DIR}/p2p-chat-windows-amd64.exe"
echo -e "  macOS:   ${DIST_DIR}/p2p-chat-darwin-amd64"
echo ""
echo -e "${BLUE}To create a GitHub release:${NC}"
echo -e "  git tag p2p-chat-v${VERSION}"
echo -e "  git push origin p2p-chat-v${VERSION}"
echo ""
