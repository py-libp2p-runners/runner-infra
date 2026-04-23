#!/bin/bash
# =============================================================================
# runner-base/entrypoint.sh
#
# Registers the runner with GitHub org and starts listening for jobs.
# Called on every container start. Deregisters on exit (EPHEMERAL=true).
#
# Required env vars:
#   ORG_NAME        — GitHub org name (e.g. py-libp2p-runners)
#   ACCESS_TOKEN    — GitHub PAT with manage_runners:org scope
#
# Optional env vars:
#   RUNNER_NAME         — defaults to hostname
#   LABELS              — comma-separated labels (default: self-hosted,linux,x64)
#   RUNNER_GROUP_NAME   — runner group (default: Default)
#   RUNNER_WORKDIR      — work directory (default: /runner-work)
#   EPHEMERAL           — true/false (default: true)
# =============================================================================

set -euo pipefail

: "${ORG_NAME:?ORG_NAME environment variable is required}"
: "${ACCESS_TOKEN:?ACCESS_TOKEN environment variable is required}"

RUNNER_NAME="${RUNNER_NAME:-$(hostname)}"
LABELS="${LABELS:-self-hosted,linux,x64}"
RUNNER_GROUP="${RUNNER_GROUP_NAME:-Default}"
RUNNER_WORKDIR="${RUNNER_WORKDIR:-/runner-work}"
EPHEMERAL="${EPHEMERAL:-true}"

mkdir -p "$RUNNER_WORKDIR"

echo "=== Registering runner: $RUNNER_NAME ==="
echo "    Org:    $ORG_NAME"
echo "    Labels: $LABELS"
echo "    Group:  $RUNNER_GROUP"

# Get registration token from GitHub API
REG_TOKEN=$(curl -fsSL \
  -X POST \
  -H "Authorization: token ${ACCESS_TOKEN}" \
  -H "Accept: application/vnd.github+json" \
  "https://api.github.com/orgs/${ORG_NAME}/actions/runners/registration-token" \
  | grep -o '"token":"[^"]*"' | cut -d'"' -f4)

if [ -z "$REG_TOKEN" ]; then
  echo "ERROR: Failed to get registration token from GitHub"
  exit 1
fi

# Configure the runner
EPHEMERAL_FLAG=""
if [ "$EPHEMERAL" = "true" ]; then
  EPHEMERAL_FLAG="--ephemeral"
fi

/actions-runner/config.sh \
  --url "https://github.com/${ORG_NAME}" \
  --token "$REG_TOKEN" \
  --name "$RUNNER_NAME" \
  --labels "$LABELS" \
  --runnergroup "$RUNNER_GROUP" \
  --work "$RUNNER_WORKDIR" \
  $EPHEMERAL_FLAG \
  --unattended \
  --replace

echo "=== Runner configured. Starting... ==="

# Cleanup on exit (deregister runner)
cleanup() {
  echo "=== Deregistering runner ==="
  REMOVE_TOKEN=$(curl -fsSL \
    -X POST \
    -H "Authorization: token ${ACCESS_TOKEN}" \
    -H "Accept: application/vnd.github+json" \
    "https://api.github.com/orgs/${ORG_NAME}/actions/runners/remove-token" \
    | grep -o '"token":"[^"]*"' | cut -d'"' -f4)
  /actions-runner/config.sh remove --token "$REMOVE_TOKEN" 2>/dev/null || true
}
trap cleanup EXIT

# Start the runner
/actions-runner/run.sh
