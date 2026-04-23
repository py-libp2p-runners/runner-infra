#!/bin/bash
# =============================================================================
# build-and-push.sh
#
# Builds and pushes all Linux runner images to GHCR in the correct order:
#   1. runner-base:linux-latest       (base — must be built first)
#   2. runner-py-libp2p:linux-latest  (uses base)
#   3. runner-go-libp2p:linux-latest  (uses base)
#   4. runner-js-libp2p:linux-latest  (uses base)
#
# Usage:
#   ./build-and-push.sh [--push] [--base-only] [--runners-only]
#
# Options:
#   --push          Push images to GHCR after building (default: build only)
#   --base-only     Only build/push the base image
#   --runners-only  Only build/push the runner images (base must already exist)
# =============================================================================

set -euo pipefail

REGISTRY="ghcr.io/py-libp2p-runners"
PLATFORM="linux/amd64"
PUSH=false
BASE_ONLY=false
RUNNERS_ONLY=false

for arg in "$@"; do
  case $arg in
    --push)          PUSH=true ;;
    --base-only)     BASE_ONLY=true ;;
    --runners-only)  RUNNERS_ONLY=true ;;
  esac
done

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
# Base image
# =============================================================================
if [ "$RUNNERS_ONLY" = "false" ]; then
  build_image \
    "${REGISTRY}/runner-base:linux-latest" \
    "runner-base/Dockerfile.linux"
fi

# =============================================================================
# Project-specific runner images
# =============================================================================
if [ "$BASE_ONLY" = "false" ]; then
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
echo "  All Linux images built successfully!"
if [ "$PUSH" = "true" ]; then
  echo "  All images pushed to GHCR."
fi
echo ""
echo "  Images:"
echo "    ${REGISTRY}/runner-base:linux-latest"
echo "    ${REGISTRY}/runner-py-libp2p:linux-latest"
echo "    ${REGISTRY}/runner-go-libp2p:linux-latest"
echo "    ${REGISTRY}/runner-js-libp2p:linux-latest"
echo "============================================================"
