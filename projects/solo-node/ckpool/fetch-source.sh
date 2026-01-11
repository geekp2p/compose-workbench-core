#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
SRC_DIR="${SCRIPT_DIR}/src"
DEFAULT_URL="https://bitbucket.org/ckolivas/ckpool-solo.git"
REPO_URL="${CKPOOL_REPO_URL:-$DEFAULT_URL}"
REPO_BRANCH="${CKPOOL_REPO_BRANCH:-solobtc}"
FORCE_FETCH="${CKPOOL_FORCE_FETCH:-0}"

usage() {
  cat <<'EOUSAGE'
Usage: ./ckpool/fetch-source.sh [options]

Options:
  -f, --force              Re-fetch sources even if ckpool/src already exists
      --url <git-url>      Override the upstream repository URL
      --branch <branch>    Override the branch to clone (default: solobtc)
  -h, --help               Show this message

Environment overrides:
  CKPOOL_REPO_URL, CKPOOL_REPO_BRANCH, CKPOOL_FORCE_FETCH
EOUSAGE
}

while [ "$#" -gt 0 ]; do
  case "$1" in
    -f|--force)
      FORCE_FETCH=1
      ;;
    --url)
      shift || { echo "[ckpool] --url requires a value" >&2; exit 1; }
      REPO_URL="$1"
      ;;
    --branch)
      shift || { echo "[ckpool] --branch requires a value" >&2; exit 1; }
      REPO_BRANCH="$1"
      ;;
    -h|--help)
      usage
      exit 0
      ;;
    *)
      echo "[ckpool] Unknown option: $1" >&2
      usage >&2
      exit 1
      ;;
  esac
  shift
done

if ! command -v git >/dev/null 2>&1; then
  echo "[ckpool] git is required to fetch the sources." >&2
  exit 1
fi

if [ -f "${SRC_DIR}/autogen.sh" ] && [ "${FORCE_FETCH}" != "1" ]; then
  echo "[ckpool] Sources already present in ${SRC_DIR}. Use --force to overwrite." >&2
  exit 0
fi

TMP_DIR="$(mktemp -d)"
cleanup() {
  rm -rf "${TMP_DIR}"
}
trap cleanup EXIT

if [ -d "${SRC_DIR}" ] && [ "${FORCE_FETCH}" = "1" ]; then
  echo "[ckpool] Removing existing sources in ${SRC_DIR}..."
  rm -rf "${SRC_DIR}"
fi

echo "[ckpool] Cloning ${REPO_URL} (branch ${REPO_BRANCH})..."
git clone --depth 1 --branch "${REPO_BRANCH}" "${REPO_URL}" "${TMP_DIR}/ckpool"

mkdir -p "${SRC_DIR}"
cp -a "${TMP_DIR}/ckpool/." "${SRC_DIR}/"
rm -rf "${SRC_DIR}/.git"

cat <<EONOTE
[ckpool] Sources copied into ${SRC_DIR}.
You can now run 'docker compose build ckpool-main --no-cache' or 'docker compose up --build'.
EONOTE