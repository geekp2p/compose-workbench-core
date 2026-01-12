#!/bin/bash

# ========================================
# Auto-Sync Current Branch Script
# ========================================
# This script syncs the CURRENT branch with its remote tracking branch
# WITHOUT switching to a different branch
# ========================================

set -e

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

echo ""
echo "==================================="
echo "   AUTO-SYNC CURRENT BRANCH"
echo "==================================="
echo ""

# Check if this is a git repository
if ! git rev-parse --is-inside-work-tree >/dev/null 2>&1; then
    echo -e "${RED}Error: This folder is not a git repository.${NC}"
    exit 1
fi

# Get current branch name
CURRENT_BRANCH=$(git rev-parse --abbrev-ref HEAD 2>/dev/null)

if [ -z "$CURRENT_BRANCH" ]; then
    echo -e "${RED}Error: Could not determine current branch${NC}"
    exit 1
fi

echo -e "${BLUE}Current branch:${NC} ${GREEN}$CURRENT_BRANCH${NC}"
echo ""

# Set remote (default: origin)
REMOTE="${1:-origin}"

# Check if remote exists
if ! git remote get-url "$REMOTE" >/dev/null 2>&1; then
    echo -e "${RED}Error: Remote '$REMOTE' does not exist${NC}"
    echo "Available remotes:"
    git remote -v
    exit 1
fi

# Check for uncommitted changes
if ! git diff --quiet 2>/dev/null; then
    echo ""
    echo -e "${YELLOW}WARNING: You have uncommitted changes!${NC}"
    echo ""
    git status --short
    echo ""
    read -p "Do you want to continue? This will DISCARD local changes! [y/N]: " -n 1 -r
    echo ""
    if [[ ! $REPLY =~ ^[Yy]$ ]]; then
        echo "Sync cancelled."
        exit 0
    fi
fi

# Save current commit hash for comparison
OLD_COMMIT=$(git rev-parse HEAD 2>/dev/null)

echo "Fetching from $REMOTE..."
if ! git fetch "$REMOTE"; then
    echo -e "${RED}Error: Failed to fetch from $REMOTE${NC}"
    exit 1
fi

# Check if remote branch exists
if ! git rev-parse "$REMOTE/$CURRENT_BRANCH" >/dev/null 2>&1; then
    echo ""
    echo -e "${RED}Error: Remote branch '$REMOTE/$CURRENT_BRANCH' does not exist${NC}"
    echo ""
    echo "Available remote branches matching '$CURRENT_BRANCH':"
    git branch -r | grep "$CURRENT_BRANCH" || echo "  (No matching branches found)"
    exit 1
fi

# Get the new commit hash from remote
NEW_COMMIT=$(git rev-parse "$REMOTE/$CURRENT_BRANCH" 2>/dev/null)

# Show what's changing if there are updates
if [ "$OLD_COMMIT" != "$NEW_COMMIT" ]; then
    echo ""
    echo "===== UPDATE SUMMARY ====="
    echo -e "Branch:  ${GREEN}$CURRENT_BRANCH${NC}"
    echo "From:    ${OLD_COMMIT:0:7}"
    echo "To:      ${NEW_COMMIT:0:7}"
    echo ""
    echo "New commits:"
    git log --oneline --color=always "$OLD_COMMIT..$NEW_COMMIT"
    echo ""
    echo "Files changed:"
    git diff --stat --color=always "$OLD_COMMIT..$NEW_COMMIT"
    echo ""
    echo "=========================="
    echo ""
else
    echo ""
    echo -e "${GREEN}✓ Already up to date - no changes detected.${NC}"
    echo ""
    exit 0
fi

echo "Syncing local branch with $REMOTE/$CURRENT_BRANCH..."
if ! git reset --hard "$REMOTE/$CURRENT_BRANCH"; then
    echo -e "${RED}Error: Failed to reset to $REMOTE/$CURRENT_BRANCH${NC}"
    exit 1
fi

if ! git clean -fd; then
    echo -e "${YELLOW}Warning: Failed to clean untracked files${NC}"
fi

echo ""
echo -e "${GREEN}✓ Done: '$CURRENT_BRANCH' now matches $REMOTE/$CURRENT_BRANCH${NC}"
echo ""
exit 0
