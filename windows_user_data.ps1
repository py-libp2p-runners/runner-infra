<powershell>
# =============================================================================
# windows_user_data.ps1
# Installs GitHub Actions runner DIRECTLY on Windows host (no Docker needed).
# This is the standard way to run Windows self-hosted runners.
# =============================================================================

$ErrorActionPreference = "Stop"
$ProgressPreference    = "SilentlyContinue"
[Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12

New-Item -ItemType Directory -Path "C:\logs" -Force | Out-Null
Start-Transcript -Path "C:\logs\user-data.log" -Append

Write-Host "=== Windows GitHub Runner Setup ==="
Write-Host "Time: $(Get-Date -Format 'u')"

# 1. Install AWS CLI
Write-Host "=== Installing AWS CLI ==="
Invoke-WebRequest -UseBasicParsing -Uri "https://awscli.amazonaws.com/AWSCLIV2.msi" -OutFile "C:\AWSCLIV2.msi"
Start-Process msiexec.exe -Wait -ArgumentList '/i C:\AWSCLIV2.msi /quiet'
$env:PATH = "C:\Pro$env:PATH = "C:\Pro$env:PATH = "C:\Pro$env:PATH =st$env:PATH =LI$env:PATH = "C:\Pro$env:PATH = "C:\Pro$env:PATH = "C:\Pro$env:PATH =st$env:PAT =$env:PATH = "C:\Pro$enC:$env:PATH = "C:\Pro$env:PATH = "C:\Pro$env:PATH = "C:\Pro$env:PATH =st$essm_pa$env:PATH = "C:\Pro$env:PATH = "C:\Pro$env:PATH = "C:\Pro$env
                                                                            -Error                   AT"; exit 1 }                                          wn                                                                            -Ens                                                           actions-runner"
New-Item -ItemType Directory -Path $RUNNER_DINew-Item -ItemType Directory -Path $RUNNER_DINecPNew-Item -ItemType Directory -Path $RUtions/New-Ir/releases/downlNew-Item -ItemType Direcions-runner-win-New-Item -ItemType Directory -Path $RUNNER_DINew-Item -ItemType Directory -Path $RUNNER_DINecPNew-Item -ItemT-DNew-Item -ItemType Directory -Path $RUNNER_DINew-Item -ItemType Direct
WriWriWriWriWriWriWriWriWriWriWriWriWriWriWriWriWriWriWriWriWriWriWriWriWriWriWriWriWriWriWriWriWriWriWriWriWriWriWriWriWriWriWriWriWriWriWriWriWriWriWriWriWriWriWriWriWriWriWriWriWriWriWriWriWriWriWriWriWriWriWriWriWriWriWriWriWriWriWriWriWriWriWriWriWriWriWriWriWriWriWriWriWriWriWriWriWriWriWriWriWriWriWriWriWriWriWriWriWriWegWriWriWriWriWriWriWriWriWriWriWriWriWriWriWriWriWriWriWriWriWriWriWriWriWriWriWriWriWriWriWriWriWriWriWriWriWriWriWriWriWriWriWriWriWriWriWriWriWriWriWriWriWriWriWriWriWriWriWriWriWriWriWriWriWriWriWriWriWriWriWriWriWriWriWriWriWriWriWriWriWriWriWriWriWriWriWriWriWriWriWriWriWriWriWriWriWriWriWriWriWriWriWriW$RUNNER_NAME `
  --labels "${runner_labels}" `
  --runnergroup "Default" `
  --work $WORKDIR `
  --unattended `
  --replace
Write-Host "=== Runner configured ==="

# 5. Install and start runner as a Windows service
Write-Host "=== Installing runner as Windows service ==="
& "$RUNNER_DIR\svc.cmd" install
& "$RUNNER_DIR\svc.cmd" start
Write-Host "=== Runner service started ==="

Write-Host "=== Setup complete — runner is registering with GitHub ==="
Stop-Transcript
</powershell>
