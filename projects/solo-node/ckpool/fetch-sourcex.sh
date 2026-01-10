#!/usr/bin/env bash
set -euo pipefail

REPO_URL="https://bitbucket.org/ckolivas/ckpool-solo.git"
REPO_BRANCH="solobtc"
SCRIPT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
SRC_DIR="${SCRIPT_DIR}/src"

printf 'Fetching ckpool sources from %s (branch %s)...\n' "$REPO_URL" "$REPO_BRANCH"
if [ -d "${SRC_DIR}/.git" ]; then
  git -C "$SRC_DIR" fetch --depth=1 origin "$REPO_BRANCH"
  git -C "$SRC_DIR" reset --hard "origin/${REPO_BRANCH}"
else
  rm -rf "$SRC_DIR"
  git clone --depth=1 --branch "$REPO_BRANCH" "$REPO_URL" "$SRC_DIR"
fi

# Preserve the placeholder file so the directory stays tracked while still ignored.
rm -f "${SRC_DIR}/.gitkeep"
touch "${SRC_DIR}/.gitkeep"

printf 'ckpool sources are now available in %s\n' "$SRC_DIR"