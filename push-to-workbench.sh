#!/bin/bash
# Script to push multi-compose-labV2 to compose-workbench-core
# สำหรับ Linux/macOS/WSL

set -e

echo "==================================="
echo "Push to compose-workbench-core"
echo "==================================="
echo ""

# Check current branch
CURRENT_BRANCH=$(git rev-parse --abbrev-ref HEAD)
echo "Current branch: $CURRENT_BRANCH"

if [ "$CURRENT_BRANCH" != "claude/migrate-compose-workbench-G4Wud" ]; then
    echo "WARNING: Not on the expected branch!"
    echo "Expected: claude/migrate-compose-workbench-G4Wud"
    echo "Current: $CURRENT_BRANCH"
    read -p "Continue anyway? (y/n) " -n 1 -r
    echo
    if [[ ! $REPLY =~ ^[Yy]$ ]]; then
        exit 1
    fi
fi

echo ""
echo "==================================="
echo "Step 1: Check Git credentials"
echo "==================================="

# Check if we can access GitHub
if git ls-remote https://github.com/geekp2p/compose-workbench-core.git HEAD &>/dev/null; then
    echo "✅ Can access compose-workbench-core (public)"
else
    echo "❌ Cannot access compose-workbench-core"
    echo ""
    echo "Please ensure you have:"
    echo "1. Git installed"
    echo "2. Network connection to GitHub"
    exit 1
fi

echo ""
echo "==================================="
echo "Step 2: Setup authentication"
echo "==================================="
echo ""
echo "Choose authentication method:"
echo "  1) HTTPS with Personal Access Token (recommended)"
echo "  2) SSH (requires SSH key setup)"
echo "  3) Try proxy (may fail with 502 error)"
echo ""
read -p "Enter choice (1-3): " AUTH_CHOICE

case $AUTH_CHOICE in
    1)
        echo ""
        echo "Go to: https://github.com/settings/tokens"
        echo "Create a token with 'repo' scope"
        echo ""
        read -p "Enter your GitHub Personal Access Token: " -s TOKEN
        echo ""

        REMOTE_URL="https://${TOKEN}@github.com/geekp2p/compose-workbench-core.git"
        ;;
    2)
        echo ""
        REMOTE_URL="git@github.com:geekp2p/compose-workbench-core.git"

        # Test SSH connection
        if ssh -T git@github.com 2>&1 | grep -q "successfully authenticated"; then
            echo "✅ SSH authentication working"
        else
            echo "❌ SSH authentication failed"
            echo ""
            echo "Please setup SSH key first:"
            echo "  https://docs.github.com/en/authentication/connecting-to-github-with-ssh"
            exit 1
        fi
        ;;
    3)
        echo ""
        echo "Using proxy (may fail with 502 error)..."
        REMOTE_URL="http://local_proxy@127.0.0.1:58681/git/geekp2p/compose-workbench-core"
        ;;
    *)
        echo "Invalid choice"
        exit 1
        ;;
esac

echo ""
echo "==================================="
echo "Step 3: Update remote URL"
echo "==================================="

# Update workbench remote
git remote set-url workbench "$REMOTE_URL" 2>/dev/null || \
    git remote add workbench "$REMOTE_URL"

echo "✅ Remote 'workbench' updated"
git remote -v | grep workbench

echo ""
echo "==================================="
echo "Step 4: Push to compose-workbench-core"
echo "==================================="
echo ""
echo "Pushing branch: $CURRENT_BRANCH"
echo "To: compose-workbench-core"
echo ""

# Push with retry logic (as per instructions)
MAX_RETRIES=4
RETRY_DELAY=2

for i in $(seq 0 $MAX_RETRIES); do
    if [ $i -gt 0 ]; then
        echo "Retry $i/$MAX_RETRIES (waiting ${RETRY_DELAY}s...)"
        sleep $RETRY_DELAY
        RETRY_DELAY=$((RETRY_DELAY * 2))  # Exponential backoff
    fi

    if git push -u workbench "$CURRENT_BRANCH"; then
        echo ""
        echo "==================================="
        echo "✅ SUCCESS!"
        echo "==================================="
        echo ""
        echo "Branch pushed to:"
        echo "  https://github.com/geekp2p/compose-workbench-core/tree/$CURRENT_BRANCH"
        echo ""
        echo "Next steps:"
        echo "  1. Create PR on GitHub"
        echo "  2. Review changes"
        echo "  3. Merge to main branch"
        echo ""
        exit 0
    fi

    if [ $i -lt $MAX_RETRIES ]; then
        echo "Push failed, retrying..."
    fi
done

echo ""
echo "==================================="
echo "❌ FAILED after $MAX_RETRIES retries"
echo "==================================="
echo ""
echo "Please check:"
echo "  1. GitHub credentials are valid"
echo "  2. You have push access to compose-workbench-core"
echo "  3. Network connection is stable"
echo ""
echo "See MIGRATION-GUIDE.md for more help"
exit 1
