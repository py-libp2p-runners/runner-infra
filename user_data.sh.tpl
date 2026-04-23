#!/bin/bash
# =============================================================================
# user_data.sh.tpl — runs on EC2 first boot
#
# What this does:
#   1. Installs Docker
#   2. Reads GitHub PAT from SSM
#   3. Pulls runner image from GHCR
#   4. Starts N runner containers (staggered to avoid GitHub API rate limiting)
#   5. Sets up a cron job to refill the pool after ephemeral runners exit
# =============================================================================

set -euo pipefail
exec > /var/log/user-data.log 2>&1  # log everything for debugging

echo "=== Starting GitHub runner setup ==="

# -----------------------------------------------------------------------------
# 1. Install Docker
# -----------------------------------------------------------------------------
apt-get update -y
apt-get install -y ca-certificates curl gnupg awscli

install -m 0755 -d /etc/apt/keyrings
curl -fsSL https://download.docker.com/linux/ubuntu/gpg \
  | gpg --dearmor -o /etc/apt/keyrings/docker.gpg
chmod a+r /etc/apt/keyrings/docker.gpg

echo \
  "deb [arch=$(dpkg --print-architecture) signed-by=/etc/apt/keyrings/docker.gpg] \
  https://download.docker.com/linux/ubuntu \
  $(. /etc/os-release && echo "$VERSION_CODENAME") stable" \
  > /etc/apt/sources.list.d/docker.list

apt-get update -y
apt-get install -y docker-ce docker-ce-cli containerd.io
systemctl enable docker
systemctl start docker

echo "=== Docker installed ==="

# -----------------------------------------------------------------------------
# 2. Read PAT from SSM
# -----------------------------------------------------------------------------
GITHUB_PAT=$(aws ssm get-parameter \
  --name "${ssm_pat_path}" \
  --with-decryption \
  --region "${aws_region}" \
  --query "Parameter.Value" \
  --output text)

echo "=== PAT fetched from SSM ==="

# -----------------------------------------------------------------------------
# 3. Authenticate with GHCR and pull runner image
#    PAT needs read:packages scope (in addition to admin:org) for GHCR pulls
# -----------------------------------------------------------------------------
echo "$GITHUB_PAT" | docker login ghcr.io -u github-actions --password-stdin
docker pull "${ghcr_image}"

echo "=== Runner image pulled ==="

# -----------------------------------------------------------------------------
# 4. Write the runner start script
#    This is called both on boot and by the cron refill job
# -----------------------------------------------------------------------------
cat > /usr/local/bin/start-runners.sh << 'SCRIPT'
#!/bin/bash
# Starts runner containers up to the desired count
# Skips if enough are already running

DESIRED=${runners_per_instance}
GHCR_IMAGE="${ghcr_image}"
GITHUB_ORG="${github_org}"
LABELS="${runner_labels}"
AWS_REGION="${aws_region}"
SSM_PAT_PATH="${ssm_pat_path}"
HOSTNAME=$(hostname)

# Count currently running runner containers
RUNNING=$(docker ps --filter "name=runner-" --format "{{.Names}}" | wc -l)
NEEDED=$((DESIRED - RUNNING))

if [ "$NEEDED" -le 0 ]; then
  echo "Pool full ($RUNNING/$DESIRED runners running), nothing to do"
  exit 0
fi

echo "Starting $NEEDED runner(s) ($RUNNING/$DESIRED currently running)"

# Re-fetch PAT (token may have rotated since boot)
GITHUB_PAT=$(aws ssm get-parameter \
  --name "$SSM_PAT_PATH" \
  --with-decryption \
  --region "$AWS_REGION" \
  --query "Parameter.Value" \
  --output text)

for i in $(seq 1 $NEEDED); do
  # Unique name per container: hostname + timestamp + index
  RUNNER_NAME="$HOSTNAME-$(date +%s)-$i"
  WORKDIR="/tmp/runner-$RUNNER_NAME"
  mkdir -p "$WORKDIR"

  docker run -d \
    --name "runner-$RUNNER_NAME" \
    --restart=no \
    -e RUNNER_SCOPE=org \
    -e ORG_NAME="$GITHUB_ORG" \
    -e RUNNER_GROUP_NAME=ec2-runners \
    -e ACCESS_TOKEN="$GITHUB_PAT" \
    -e RUNNER_NAME="$RUNNER_NAME" \
    -e LABELS="$LABELS" \
    -e EPHEMERAL=true \
    -e RUNNER_WORKDIR="$WORKDIR" \
    -v /var/run/docker.sock:/var/run/docker.sock \
    -v "$WORKDIR:$WORKDIR" \
    "$GHCR_IMAGE"

  echo "Started runner: $RUNNER_NAME"

  # Stagger startup — avoids GitHub API rate limiting on registration tokens
  sleep 5
done
SCRIPT

chmod +x /usr/local/bin/start-runners.sh

# -----------------------------------------------------------------------------
# 5. Start runners for the first time
# -----------------------------------------------------------------------------
/usr/local/bin/start-runners.sh

echo "=== Initial runners started ==="

# -----------------------------------------------------------------------------
# 6. Cron job — refills pool every 5 minutes
#    Ephemeral runners exit after 1 job. Cron keeps the pool full.
# -----------------------------------------------------------------------------
echo "*/5 * * * * root /usr/local/bin/start-runners.sh >> /var/log/runner-refill.log 2>&1" \
  > /etc/cron.d/github-runner-refill

chmod 644 /etc/cron.d/github-runner-refill
systemctl restart cron

echo "=== Cron refill job configured ==="
echo "=== Setup complete — runners are registering with GitHub ==="
