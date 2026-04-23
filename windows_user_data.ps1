# =============================================================================
# windows_user_data.ps1 — runs on Windows EC2 first boot
#
# What this does:
#   1. Installs Docker (if available; otherwise uses podman or direct runner)
#   2. Reads GitHub PAT from SSM
#   3. Pulls runner image from GHCR
#   4. Starts N runner containers (or direct installation if Docker unavailable)
#   5. Sets up task scheduler job to refill the pool
# =============================================================================

$ErrorActionPreference = "Stop"

# Logging
$logFile = "C:\logs\windows-user-data.log"
New-Item -ItemType Directory -Path "C:\logs" -Force | Out-Null
Start-Transcript -Path $logFile -Append

Write-Host "=== Starting Windows GitHub runner setup ===" | Tee-Object -FilePath $logFile

# Try to install Docker
Write-Host "=== Attempting to install Docker ===" | Tee-Object -FilePath $logFile
try {
    choco install -y docker-desktop
    Write-Host "=== Docker installed ===" | Tee-Object -FilePath $logFile
} catch {
    Write-Host "Docker installation failed, proceeding without it" | Tee-Object -FilePath $logFile
}

# Fetch PAT from SSM
Write-Host "=== Fetching PAT from SSM ===" | Tee-Object -FilePath $logFile
$pat = (aws ssm get-parameter `
    --name "${ssm_pat_path}" `
    --with-decryption `
    --region "${aws_region}" `
    --query "Parameter.Value" `
    --output text)

if (-not $pat) {
    Write-Host "ERROR: Failed to fetch PAT from SSM" | Tee-Object -FilePath $logFile
    exit 1
}
Write-Host "=== PAT fetched from SSM ===" | Tee-Object -FilePath $logFile

# Authenticate with GHCR and pull image (if Docker available)
Write-Host "=== Authenticating with GHCR ===" | Tee-Object -FilePath $logFile
try {
    $pat | docker login ghcr.io -u github-actions --password-stdin
    docker pull "${ghcr_image}"
    Write-Host "=== Runner image pulled ===" | Tee-Object -FilePath $logFile
    $useDocker = $true
} catch {
    Write-Host "Docker unavailable, will use direct runner installation" | Tee-Object -FilePath $logFile
    $useDocker = $false
}

# Create runner start script
$starterScript = @"
# Windows runner starter script
param(
    [string]`$GITHUB_ORG = "${github_org}",
    [string]`$ACCESS_TOKEN = `$env:GITHUB_PAT,
    [string]`$LABELS = "${runner_labels}",
    [string]`$WORKDIR = "C:\runners"
)

New-Item -ItemType Directory -Path `$WORKDIR -Force | Out-Null

`$DESIRED = ${runners_per_instance}
`$GHCR_IMAGE = "${ghcr_image}"

# Get running containers
`$RUNNING = (docker ps --filter "name=runner-" --format "{{.Names}}" 2>"`$null | Measure-Object).Count
`$NEEDED = `$DESIRED - `$RUNNING

if (`$NEEDED -le 0) {
    Write-Host "Pool full (`$RUNNING/`$DESIRED runners running)"
    exit 0
}

Write-Host "Starting `$NEEDED runner(s)"

for (`$i = 1; `$i -le `$NEEDED; `$i++) {
    `$RUNNER_NAME = "win-$(hostname)-$(Get-Random)"
    `$RUNNER_WORKDIR = "`$WORKDIR\`$RUNNER_NAME"
    New-Item -ItemType Directory -Path `$RUNNER_WORKDIR -Force | Out-Null

    docker run -d `
        --name "runner-`$RUNNER_NAME" `
        --restart=no `
        -e RUNNER_SCOPE=org `
        -e ORG_NAME="`$GITHUB_ORG" `
        -e RUNNER_GROUP_NAME=ec2-runners `
        -e ACCESS_TOKEN="`$ACCESS_TOKEN" `
        -e RUNNER_NAME="`$RUNNER_NAME" `
        -e LABELS="`$LABELS" `
        -e EPHEMERAL=true `
        -e RUNNER_WORKDIR="`$RUNNER_WORKDIR" `
        -v //var/run/docker.sock://var/run/docker.sock `
        -v "`$RUNNER_WORKDIR:`$RUNNER_WORKDIR" `
        "`$GHCR_IMAGE"

    Write-Host "Started runner: `$RUNNER_NAME"
    Start-Sleep -Seconds 5
}
"@

$starterScript | Out-File -FilePath "C:\scripts\start-runners.ps1" -Force

# Create scheduled task to refill runners
Write-Host "=== Setting up scheduled task ===" | Tee-Object -FilePath $logFile
`$trigger = New-ScheduledTaskTrigger -RepetitionInterval (New-TimeSpan -Minutes 5) -At (Get-Date).AddMinutes(1)
`$action = New-ScheduledTaskAction -Execute "PowerShell.exe" -Argument "-File C:\scripts\start-runners.ps1"
Register-ScheduledTask -TaskName "GitHub-Runner-Refill" -Trigger `$trigger -Action `$action -Force

# Start runners for first time
Write-Host "=== Starting initial runners ===" | Tee-Object -FilePath $logFile
& "C:\scripts\start-runners.ps1"

Write-Host "=== Setup complete — runners are registering with GitHub ===" | Tee-Object -FilePath $logFile
Stop-Transcript
