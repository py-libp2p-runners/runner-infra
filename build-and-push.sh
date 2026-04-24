#!/bin/bash
# =============================================================================
# build-and-push.sh
#
# Phase 1: Builds and pushes base runner images only.
# Phase 2 (--all): Also builds language-specific runner images.
#
# Build order:
#   Phase 1:  runner-base:linux-latest        (base — must be built first)
#   Phase 2:  runner-py-libp2p:linux-latest   (uses base, --all only)
#             runner-go-libp2p:linux-latest   (uses base, --all only)
#             runner-js-libp2p:linux-latest   (uses base, --all only)
#
# Usage:
#   ./build-and-push.sh [--push] [--all]
#
# Options:
#   --push   Push images to GHCR after building (default: build only)
#   --all    Also build/push language-specific runner images (Phase 2)
# =============================================================================

set -euo pipefail

REGISTRY="ghcr.io/py-libp2p-runners"
PLATFORM="linux/amd64"
PUSH=false
ALL=false

for arg in "$@"; do
  case $arg in
    --push) PUSH=true ;;
    --all)  ALL=true ;;
  esac
done

# Legacy compat — treat --base-only as default (no-op) and --runners-only as --all
BASE_ONLY=false
RUNNERS_ONLY=false

build_image() {
  local tag="$1"
  local dockerfile="$2"
  local context="${3:-.}"

  echo ""
  echo "============================================================"
  echo "  Building: $tag"
  echo "  Dockerfile: $dockerfile"
  echo "============================================================"

  docker build \
    --platform "$PLATFORM" \
    -f "$dockerfile" \
    -t "$tag" \
    "$context"

  if [ "$PUSH" = "true" ]; then
    echo "  Pushing: $tag"
    docker push "$tag"
  fi
}

# Login to GHCR (requires GITHUB_TOKEN or GITHUB_PAT env var)
if [ "$PUSH" = "true" ]; then
  if [ -z "${GITHUB_TOKEN:-}" ] && [ -z "${GITHUB_PAT:-}" ]; then
    echo "ERROR: Set GITHUB_TOKEN or GITHUB_PAT to push to GHCR"
    exit 1
  fi
  TOKEN="${GITHUB_TOKEN:-$GITHUB_PAT}"
  echo "$TOKEN" | docker login ghcr.io -u github-actions --password-stdin
fi

# =============================================================================
# Phase 1 — Base image (always built)
# =============================================================================
build_image \
  "${REGISTRY}/runner-base:linux-latest" \
  "runner-base/Dockerfile.linux"

# =============================================================================
# Phase 2 — Language-specific runner images (only with --all)
# =============================================================================
if [ "$ALL" = "true" ]; then
  build_image \
    "${REGISTRY}/runner-py-libp2p:linux-latest" \
    "runners/py-libp2p/Dockerfile.linux"

  build_image \
    "${REGISTRY}/runner-go-libp2p:linux-latest" \
    "runners/go-libp2p/Dockerfile.linux"

  build_image \
    "${REGISTRY}/runner-js-libp2p:linux-latest" \
    "runners/js-libp2p/Dockerfile.linux"
fi

echo ""
echo "============================================================"
echo "  Build complete!"
if [ "$PUSH" = "true" ]; then
  echo "  Images pushed to GHCR."
fi
echo ""
echo "  Built images:"
echo "    ${REGISTRY}/runner-base:linux-latest"
if [ "$ALL" = "true" ]; then
  echo "    ${REGISTRY}/runner-py-libp2p:linux-latest"
  echo "    ${REGISTRY}/runner-go-libp2p:linux-latest"
  echo "    ${REGISTRY}/runner-js-libp2p:linux-latest"
fi
echo "============================================================"
