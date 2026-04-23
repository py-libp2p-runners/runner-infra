# =============================================================================
# runner-base/entrypoint.ps1
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
#   LABELS              — comma-separated labels (default: self-hosted,windows,x64)
#   RUNNER_GROUP_NAME   — runner group (default: Default)
#   RUNNER_WORKDIR      — work directory (default: C:\runner-work)
#   EPHEMERAL           — true/false (default: true)
# =============================================================================

$ErrorActionPreference = "Stop"

# Validate required env vars
if (-not $env:ORG_NAME)     { Write-Error "ORG_NAME is required";     exit 1 }
if (-not $env:ACCESS_TOKEN) { Write-Error "ACCESS_TOKEN is required"; exit 1 }

$RUNNER_NAME   = if ($env:RUNNER_NAME)       { $env:RUNNER_NAME }       else { hostname }
$LABELS        = if ($env:LABELS)            { $env:LABELS }            else { "self-hosted,windows,x64" }
$RUNNER_GROUP  = if ($env:RUNNER_GROUP_NAME) { $env:RUNNER_GROUP_NAME } else { "Default" }
$RUNNER_WORKDIR = if ($env:RUNNER_WORKDIR)   { $env:RUNNER_WORKDIR }    else { "C:\runner-work" }
$EPHEMERAL     = if ($env:EPHEMERAL)         { $env:EPHEMERAL }         else { "true" }

New-Item -ItemType Directory -Path $RUNNER_WORKDIR -Force | Out-Null

Write-Host "=== Registering runner: $RUNNER_NAME ==="
Write-Host "    Org:    $($env:ORG_NAME)"
Write-Host "    Labels: $LABELS"
Write-Host "    Group:  $RUNNER_GROUP"

# Get registration token from GitHub API
$headers = @{
    "Authorization" = "token $($env:ACCESS_TOKEN)"
    "Accept"        = "application/vnd.github+json"
}
$response = Invoke-RestMethod `
    -Uri "https://api.github.com/orgs/$($env:ORG_NAME)/actions/runners/registration-token" `
    -Method POST `
    -Headers $headers

$REG_TOKEN = $response.token
if (-not $REG_TOKEN) {
    Write-Error "Failed to get registration token from GitHub"
    exit 1
}

# Build config arguments
$configArgs = @(
    "--url", "https://github.com/$($env:ORG_NAME)",
    "--token", $REG_TOKEN,
    "--name", $RUNNER_NAME,
    "--labels", $LABELS,
    "--runnergroup", $RUNNER_GROUP,
    "--work", $RUNNER_WORKDIR,
    "--unattended",
    "--replace"
)
if ($EPHEMERAL -eq "true") { $configArgs += "--ephemeral" }

# Configure the runner
& C:\actions-runner\config.cmd @configArgs
if ($LASTEXITCODE -ne 0) {
    Write-Error "Runner configuration failed with exit code $LASTEXITCODE"
    exit 1
}

Write-Host "=== Runner configured. Starting... ==="

# Deregister on exit
$cleanup = {
    Write-Host "=== Deregistering runner ==="
    try {
        $removeResponse = Invoke-RestMethod `
            -Uri "https://api.github.com/orgs/$($env:ORG_NAME)/actions/runners/remove-token" `
            -Method POST `
            -Headers $headers
        & C:\actions-runner\config.cmd remove --token $removeResponse.token 2>$null
    } catch { }
}
Register-EngineEvent -SourceIdentifier PowerShell.Exiting -Action $cleanup | Out-Null

# Start the runner
& C:\actions-runner\run.cmd

Write-Host "Runner exited."
