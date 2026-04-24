<powershell>
# =============================================================================
# windows_user_data.ps1 — runs on Windows EC2 first boot via EC2 user data
#
# What this does:
#   1. Enables Windows Containers feature + installs Docker Engine
#   2. Reads GitHub PAT from SSM Parameter Store
#   3. Authenticates with GHCR and pulls the runner image
#   4. Starts N runner containers (each registers with GitHub on start)
#   5. Sets up a scheduled task to refill the pool every 5 minutes
# =============================================================================

$ErrorActionPreference = "Stop"
$ProgressPreference    = "SilentlyContinue"

New-Item -ItemType Directory -Path "C:\logs" -Force | Out-Null
Start-Transcript -Path "C:\logs\user-data.log" -Append

Write-Host "=== Windows GitHub Runner Setup Starting ==="
Write-Host "Time: $(Get-Date -Format 'u')"

# -----------------------------------------------------------------------------
# 1. Install Docker Engine (Windows Server — NOT Docker Desktop)
#    Uses the official Microsoft Windows Containers install script.
# -----------------------------------------------------------------------------
Write-Host "=== Installing Docker Engine ==="

# Containers Windows feature is required for Windows container images
Install-WindowsFeature -Name Containers -Restart:$false

[Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12
Invoke-WebRequest -UseBasicParsing `
  -Uri "https://raw.githubusercontent.com/microsoft/Windows-Containers/Main/helpful_tools/Install-DockerCE/install-docker-ce.ps1" `
  -OutFile "C:\install-docker-ce.ps1"
& "C:\install-docker-ce.ps1" -NoRestart

Start-Service docker
Write-Host "=== Docker Engine installed and started ==="
docker version

# -----------------------------------------------------------------------------
# 2. Install AWS CLI (for SSM parameter retrieval)
# -----------------------------------------------------------------------------
Write-Host "=== Installing AWS CLI ==="
Invoke-WebRequest -UseBasicParsing `
  -Uri "https://awscli.amazonaws.com/AWSCLIV2.msi" `
  -OutFile "C:\AWSCLIV2.msi"
Start-Process msiexec.exe -Wait -ArgumentList '/i C:\AWSCLIV2.msi /quiet'
$env:PATH = "C:\Program Files\Amazon\AWSCLIV2;" + $env:PATH
Write-Host "=== AWS CLI installed ==="

# -----------------------------------------------------------------------------
# 3. Fetch GitHub PAT from SSM
# -----------------------------------------------------------------------------
Write-Host "=== Fetching PAT from SSM ==="
$GITHUB_PAT = (aws ssm get-parameter `
  --name "${ssm_pat_path}" `
  --with-decryption `
  --region "${aws_region}" `
  --query "Parameter.Value" `
  --output text)

if (-not $GITHUB_PAT) {
  Write-Error "ERROR: Failed to fetch PAT from SSM"
  exit 1
}
Write-Host "=== PAT fetched from SSM ==="

# -----------------------------------------------------------------------------
# 4. Authenticate with GHCR and pull runner image
# -----------------------------------------------------------------------------
Write-Host "=== Authenticating with GHCR ==="
$GITHUB_PAT | docker login ghcr.io -u github-actions --password-stdin
docker pull "${ghcr_image}"
Write-Host "=== Runner image pulled: ${ghcr_image} ==="

# -----------------------------------------------------------------------------
# 5. Write the pool management script
# -----------------------------------------------------------------------------
New-Item -ItemType Directory -Path "C:\scripts" -Force | Out-Null

@"
# =============================================================================
# C:\scripts\start-runners.ps1 — starts runner containers up to desired count
# =============================================================================
`$ErrorActionPreference = "Stop"
`$ProgressPreference    = "SilentlyContinue"

`$DESIRED      = ${runners_per_instance}
`$GHCR_IMAGE   = "${ghcr_image}"
`$GITHUB_ORG   = "${github_org}"
`$LABELS       = "${runner_labels}"
`$AWS_REGION   = "${aws_region}"
`$SSM_PAT_PATH = "${ssm_pat_path}"
`$HOSTNAME_VAL = `$env:COMPUTERNAME

`$RUNNING = @(docker ps --filter "name=runner-" --format "{{.Names}}" 2>`$null).Count
`$NEEDED  = `$DESIRED - `$RUNNING

if (`$NEEDED -le 0) {
  Write-Host "Pool full (`$RUNNING/`$DESIRED runners running), nothing to do"
  exit 0
}
Write-Host "Starting `$NEEDED runner(s) (`$RUNNING/`$DESIRED currently running)"

`$GITHUB_PAT = (aws ssm get-parameter ``
  --name `$SSM_PAT_PATH ``
  --with-decryption ``
  --region `$AWS_REGION ``
  --query "Parameter.Value" ``
  --output text)

for (`$i = 1; `$i -le `$NEEDED; `$i++) {
  `$RUNNER_NAME = "`$HOSTNAME_VAL-`$([DateTimeOffset]::UtcNow.ToUnixTimeSeconds())-`$i"
  `$WORKDIR     = "C:\runner-work\`$RUNNER_NAME"
  New-Item -ItemType Directory -Path `$WORKDIR -Force | Out-Null

  docker run -d ``
    --name "runner-`$RUNNER_NAME" ``
    --restart no ``
    -e ORG_NAME="`$GITHUB_ORG" ``
    -e RUNNER_GROUP_NAME="Default" ``
    -e ACCESS_TOKEN="`$GITHUB_PAT" ``
    -e RUNNER_NAME="`$RUNNER_NAME" ``
    -e LABELS="`$LABELS" ``
    -e EPHEMERAL="true" ``
    -e RUNNER_WORKDIR="C:\runner-work" ``
    -v "`$WORKDIR`:C:\runner-work" ``
    "`$GHCR_IMAGE"

  Write-Host "Started runner: `$RUNNER_NAME"
  Start-Sleep -Seconds 5
}
"@ | Out-File -FilePath "C:\scripts\start-runners.ps1" -Encoding UTF8 -Force

Write-Host "=== start-runners.ps1 written ==="

# -----------------------------------------------------------------------------
# 6. Start runners for the first time
# -----------------------------------------------------------------------------
Write-Host "=== Starting initial runner containers ==="
& "C:\scripts\start-runners.ps1"
Write-Host "=== Initial runners started ==="

# -----------------------------------------------------------------------------
# 7. Scheduled task — refills pool every 5 minutes
# -----------------------------------------------------------------------------
Write-Host "=== Setting up scheduled task for pool refill ==="

$action   = New-ScheduledTaskAction `
  -Execute "powershell.exe" `
  -Argument "-NonInteractive -NoProfile -File C:\scripts\start-runners.ps1"

$trigger  = New-ScheduledTaskTrigger `
  -RepetitionInterval (New-TimeSpan -Minutes 5) `
  -Once `
  -At (Get-Date).AddMinutes(1)

$settings = New-ScheduledTaskSettingsSet `
  -ExecutionTimeLimit (New-TimeSpan -Minutes 4) `
  -RestartCount 0

Register-ScheduledTask `
  -TaskName   "GitHub-Runner-Refill" `
  -Action     $action `
  -Trigger    $trigger `
  -Settings   $settings `
  -RunLevel   Highest `
  -Force

Write-Host "=== Scheduled task registered ==="
Write-Host "=== Setup complete — runners are registering with GitHub ==="
Stop-Transcript
</powershell>
Stop-Transcript
