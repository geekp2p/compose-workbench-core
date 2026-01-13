#!/usr/bin/env bash
# P2P Chat GitHub Release Upload Script
# Automatically creates tags and uploads release binaries
# Compatible with Linux and macOS

set -euo pipefail

# Configuration
APP_NAME="p2p-chat"
DIST_DIR="../../dist"
REPO="geekp2p/compose-workbench-core"
VERSION=""
DRY_RUN=false

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
MAGENTA='\033[0;35m'
NC='\033[0m' # No Color

# Parse arguments
while [[ $# -gt 0 ]]; do
    case $1 in
        -v|--version)
            VERSION="$2"
            shift 2
            ;;
        --dry-run)
            DRY_RUN=true
            shift
            ;;
        -h|--help)
            echo "Usage: $0 [-v VERSION] [--dry-run]"
            echo ""
            echo "Options:"
            echo "  -v, --version VERSION  Specify version (default: read from updater.go)"
            echo "  --dry-run              Show what would be done without making changes"
            echo "  -h, --help             Show this help message"
            exit 0
            ;;
        *)
            echo "Unknown option: $1"
            echo "Use -h or --help for usage information"
            exit 1
            ;;
    esac
done

# Print banner
echo ""
echo -e "${BLUE}+===================================================+${NC}"
echo -e "${BLUE}|     P2P Chat GitHub Release Uploader             |${NC}"
echo -e "${BLUE}+===================================================+${NC}"
echo ""

# Get version from updater.go if not specified
if [ -z "$VERSION" ]; then
    if [ -f "internal/updater/updater.go" ]; then
        VERSION=$(grep 'var Version = ' internal/updater/updater.go | sed 's/.*"\(.*\)".*/\1/')
        if [ -z "$VERSION" ]; then
            echo -e "${RED}Error: Could not extract version from updater.go${NC}"
            exit 1
        fi
        echo -e "${CYAN}Using version from updater.go: $VERSION${NC}"
    else
        echo -e "${RED}Error: updater.go not found${NC}"
        exit 1
    fi
else
    echo -e "${GREEN}Using specified version: $VERSION${NC}"
fi

TAG_NAME="${APP_NAME}-v${VERSION}"
echo ""

# Check if gh CLI is installed
if ! command -v gh &> /dev/null; then
    echo -e "${RED}Error: GitHub CLI (gh) is not installed${NC}"
    echo -e "${YELLOW}Install from: https://cli.github.com/${NC}"
    exit 1
fi
echo -e "${GREEN}[OK] GitHub CLI is installed${NC}"
echo ""

# Check if authenticated
if ! gh auth status &> /dev/null; then
    echo -e "${RED}Error: Not authenticated with GitHub${NC}"
    echo -e "${YELLOW}Run: gh auth login${NC}"
    exit 1
fi
echo -e "${GREEN}[OK] Authenticated with GitHub${NC}"
echo ""

# Check if dist directory exists
if [ ! -d "$DIST_DIR" ]; then
    echo -e "${RED}Error: Distribution directory not found: $DIST_DIR${NC}"
    echo -e "${YELLOW}Run build-release.sh first${NC}"
    exit 1
fi

# Count binaries
BINARY_COUNT=$(find "$DIST_DIR" -type f -name "${APP_NAME}-*" ! -name "*.txt" | wc -l)
if [ "$BINARY_COUNT" -eq 0 ]; then
    echo -e "${RED}Error: No binaries found in $DIST_DIR${NC}"
    echo -e "${YELLOW}Run build-release.sh first${NC}"
    exit 1
fi

echo -e "${GREEN}Found $BINARY_COUNT binaries to upload:${NC}"
find "$DIST_DIR" -type f -name "${APP_NAME}-*" ! -name "*.txt" | while read -r binary; do
    size=$(du -h "$binary" | cut -f1)
    echo "  - $(basename "$binary") ($size)"
done
echo ""

# Check for checksums file
CHECKSUM_FILE="$DIST_DIR/checksums.txt"
if [ -f "$CHECKSUM_FILE" ]; then
    echo -e "${GREEN}[OK] Checksums file found${NC}"
else
    echo -e "${YELLOW}Warning: checksums.txt not found${NC}"
fi
echo ""

# Check if tag already exists
echo -e "${BLUE}Checking if tag $TAG_NAME exists...${NC}"
if git rev-parse "$TAG_NAME" &> /dev/null; then
    echo -e "${YELLOW}Tag $TAG_NAME already exists locally${NC}"
fi

# Check remote tag
if git ls-remote --tags origin "$TAG_NAME" | grep -q "$TAG_NAME"; then
    echo -e "${YELLOW}Tag $TAG_NAME already exists on remote${NC}"
    echo -e "${RED}Error: Release tag already exists. Increment version or delete the tag first.${NC}"
    exit 1
fi

if ! git rev-parse "$TAG_NAME" &> /dev/null; then
    echo -e "${BLUE}Creating tag $TAG_NAME...${NC}"

    if [ "$DRY_RUN" = true ]; then
        echo -e "${MAGENTA}[DRY RUN] Would create tag: $TAG_NAME${NC}"
    else
        git tag -a "$TAG_NAME" -m "Release v${VERSION}"
        echo -e "${GREEN}[OK] Tag created: $TAG_NAME${NC}"
    fi
    echo ""
fi

# Push tag to remote
echo -e "${BLUE}Pushing tag to remote...${NC}"
if [ "$DRY_RUN" = true ]; then
    echo -e "${MAGENTA}[DRY RUN] Would push tag to origin${NC}"
else
    git push origin "$TAG_NAME"
    echo -e "${GREEN}[OK] Tag pushed to remote${NC}"
fi
echo ""

# Create release notes
RELEASE_NOTES=$(cat <<EOF
# P2P Chat v${VERSION}

Cross-platform P2P chat application built with libp2p.

## Features
- Decentralized peer-to-peer messaging
- Auto-discovery on local network
- Topic-based chat rooms
- Cross-platform support (Linux, Windows, macOS)
- Multi-architecture support (amd64, arm64)

## Installation

Download the appropriate binary for your platform:

**Linux (amd64):**
\`\`\`bash
wget https://github.com/${REPO}/releases/download/${TAG_NAME}/p2p-chat-linux-amd64
chmod +x p2p-chat-linux-amd64
./p2p-chat-linux-amd64
\`\`\`

**Linux (arm64):**
\`\`\`bash
wget https://github.com/${REPO}/releases/download/${TAG_NAME}/p2p-chat-linux-arm64
chmod +x p2p-chat-linux-arm64
./p2p-chat-linux-arm64
\`\`\`

**Windows (amd64):**
Download and run: [p2p-chat-windows-amd64.exe](https://github.com/${REPO}/releases/download/${TAG_NAME}/p2p-chat-windows-amd64.exe)

**macOS (Intel):**
\`\`\`bash
wget https://github.com/${REPO}/releases/download/${TAG_NAME}/p2p-chat-darwin-amd64
chmod +x p2p-chat-darwin-amd64
./p2p-chat-darwin-amd64
\`\`\`

**macOS (Apple Silicon):**
\`\`\`bash
wget https://github.com/${REPO}/releases/download/${TAG_NAME}/p2p-chat-darwin-arm64
chmod +x p2p-chat-darwin-arm64
./p2p-chat-darwin-arm64
\`\`\`

## Verification

Verify the downloaded binary using SHA256 checksums:

\`\`\`bash
sha256sum -c checksums.txt
\`\`\`

## What's New in v${VERSION}
- Initial release
- Basic P2P chat functionality
- Support for 6 platforms (Linux, Windows, macOS on amd64 and arm64)
EOF
)

# Create GitHub release
echo -e "${BLUE}Creating GitHub release...${NC}"
if [ "$DRY_RUN" = true ]; then
    echo -e "${MAGENTA}[DRY RUN] Would create release with:${NC}"
    echo "  Tag: $TAG_NAME"
    echo "  Title: P2P Chat v${VERSION}"
    echo "  Files: $BINARY_COUNT binaries + checksums.txt"
else
    gh release create "$TAG_NAME" \
        --repo "$REPO" \
        --title "P2P Chat v${VERSION}" \
        --notes "$RELEASE_NOTES"
    echo -e "${GREEN}[OK] GitHub release created${NC}"
fi
echo ""

# Upload binaries
echo -e "${BLUE}Uploading binaries to release...${NC}"
echo ""

UPLOAD_SUCCESS=0
UPLOAD_FAILED=0

find "$DIST_DIR" -type f -name "${APP_NAME}-*" ! -name "*.txt" | while read -r binary; do
    filename=$(basename "$binary")
    echo -e "${YELLOW}Uploading $filename...${NC}"

    if [ "$DRY_RUN" = true ]; then
        echo -e "${MAGENTA}[DRY RUN] Would upload: $filename${NC}"
        ((UPLOAD_SUCCESS++))
    else
        if gh release upload "$TAG_NAME" "$binary" --repo "$REPO" --clobber; then
            echo -e "${GREEN}[OK] Uploaded: $filename${NC}"
            ((UPLOAD_SUCCESS++))
        else
            echo -e "${RED}[FAIL] Failed to upload: $filename${NC}"
            ((UPLOAD_FAILED++))
        fi
    fi
done

# Upload checksums
if [ -f "$CHECKSUM_FILE" ]; then
    echo ""
    echo -e "${YELLOW}Uploading checksums.txt...${NC}"

    if [ "$DRY_RUN" = true ]; then
        echo -e "${MAGENTA}[DRY RUN] Would upload: checksums.txt${NC}"
    else
        if gh release upload "$TAG_NAME" "$CHECKSUM_FILE" --repo "$REPO" --clobber; then
            echo -e "${GREEN}[OK] Uploaded: checksums.txt${NC}"
        else
            echo -e "${RED}[FAIL] Failed to upload checksums.txt${NC}"
            ((UPLOAD_FAILED++))
        fi
    fi
fi

echo ""

# Summary
echo -e "${BLUE}+===================================================+${NC}"
echo -e "${BLUE}|              Upload Summary                       |${NC}"
echo -e "${BLUE}+===================================================+${NC}"
echo -e "${GREEN}Version:     $VERSION${NC}"
echo -e "${GREEN}Tag:         $TAG_NAME${NC}"
echo -e "${GREEN}Uploaded:    $UPLOAD_SUCCESS files${NC}"
if [ "$UPLOAD_FAILED" -gt 0 ]; then
    echo -e "${RED}Failed:      $UPLOAD_FAILED files${NC}"
fi
echo ""

if [ "$DRY_RUN" = true ]; then
    echo -e "${MAGENTA}[DRY RUN] No actual changes were made${NC}"
    echo -e "${YELLOW}Run without --dry-run to perform the upload${NC}"
else
    echo -e "${GREEN}[OK] Release upload completed!${NC}"
    echo ""
    echo -e "${BLUE}View release at:${NC}"
    echo "  https://github.com/${REPO}/releases/tag/${TAG_NAME}"
fi

echo ""
