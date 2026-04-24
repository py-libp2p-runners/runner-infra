# GitHub Self-Hosted Runners Deployment Status

## 🎯 Objective
Automate the end-to-end creation, build, and deployment of multi-platform (Linux and Windows) GitHub Actions self-hosted runners. This includes:
- Dockerizing base runner environments and language-specific environments (Python, Go, Node.js).
- Deploying AWS infrastructure (EC2) using Terraform to host and run the Linux Docker containers.
- Automating Windows container builds via a remote GitHub Actions pipeline (since they cannot be built locally on macOS).

## ✅ What We Have Achieved
- **Dockerfiles Designed:** Created base and language-specific Dockerfiles for both Linux and Windows operating systems.
- **Infrastructure Deployed:** Applied the AWS infrastructure using Terraform, successfully spinning up a `t3.medium` EC2 instance (`i-0770928e060a4d14d`, public IP `16.170.98.124`, region `eu-north-1`), required IAM instance profiles, and auto-provisioning scripts via user data. Instance is currently **running**.
- **Windows CI Pipeline:** Triggered a GitHub Actions workflow (`build-windows-runners.yml`) to build the Windows runner images remotely and push them to GHCR. We also resolved initial build errors related to relative copy paths and pre-existing Visual Studio build tools.
- **Git Security Cleanup:** Rewrote the Git history to remove `.terraform` directories and state files that contained sensitive AWS/registration secrets.
- **Permissions Restructuring:** Configured the Linux Dockerfiles to create and utilize a non-root `runner` user, complying with GitHub's strict `Must not run with sudo` runner requirement while ensuring that tool installations (`apt-get`) continue to execute as root beforehand.
- **Linux CI Pipeline Added:** Created `.github/workflows/build-linux-runners.yml` — mirrors the Windows workflow but runs on `ubuntu-latest`. Uses `docker/build-push-action` with GitHub Actions cache (`type=gha`) for fast rebuilds. Triggers on pushes to `main` that touch any Linux Dockerfile or the workflow itself, plus manual `workflow_dispatch`.
- **Dockerfile Bugs Fixed:**
  - `runners/py-libp2p/Dockerfile.linux`: Fixed `uv` install — now installs to `/usr/local/bin` (via `UV_INSTALL_DIR`) instead of `/root/.local/bin`, so the binary is on PATH for the non-root `runner` user.
  - `runners/go-libp2p/Dockerfile.linux`: Fixed `GOPATH` — changed from `/go` (root-owned) to `/home/runner/go` and pre-created with correct ownership, so Go tools are accessible after `USER runner`.

## ⏳ Left to Achieve
- **Build & Push Linux Images:** Once Docker Desktop is healthy (see Docker fix below), run `./build-and-push.sh --push` to build all 4 Linux images and push to GHCR. Alternatively, push the current branch to `main` to trigger the new `build-linux-runners.yml` CI pipeline — this is the more reliable path.
- **Restart EC2 Runner Containers:** SSH into the EC2 instance (`16.170.98.124`), remove any crashed containers, and start new ones using the updated `runner` user images from GHCR.
- **Confirm Runner Registration:** Verify the runners successfully execute their entrypoint script, register with the GitHub API, and appear as "Online" inside your GitHub repository settings.
- **Finalize Windows Pipeline:** Ensure the GitHub Actions Windows runner build pushes completed payloads successfully to GHCR.

## 🚧 Current Limitations & Ongoing Problems
- **Local Docker Desktop I/O Faults:** The Docker Desktop containerd daemon has a corrupted blob (`sha256:e92df5d5...`) in its content store, causing `input/output error` on all `docker images` / `docker build` calls. Root cause: exhausted or corrupted virtual disk inside Docker Desktop's VM. **Fix in progress:** Docker Desktop was restarted. If the error persists after restart, perform a **"Clean / Purge data"** from Docker Desktop → Troubleshoot → Clean / Purge Data (this wipes all local images/containers but fixes the corruption). Since no runner images exist locally yet, this is safe.
- **GitHub Runner Root Constraints:** GitHub strictly forbids running the `actions-runner` configuration and execution process as the root user. Juggling root privileges for dependencies (`apt-get`) while running the entrypoint under standard permissions caused early deployment failures (Exit Code 1). **Resolved** via non-root `runner` user + fixed tool paths.
- **Cross-Platform Build Limitations:** Because you are on macOS, we cannot locally build or test Windows Server containers. This breaks the local feedback loop for Windows and forces us to rely entirely on push-and-pray commits to GitHub Actions for testing Windows Dockerfiles.

## 🔧 How to Complete the Deployment

### Step 1 — Fix Docker Desktop (if still broken)
Open Docker Desktop → click the bug icon (Troubleshoot) → **"Clean / Purge data"** → confirm. This resets the VM disk and clears the I/O error. Docker will restart cleanly.

### Step 2 — Build & Push Linux Images (two options)

**Option A — CI (recommended, no local Docker needed):**
```bash
git add -A && git commit -m "fix: uv PATH, GOPATH, add Linux CI workflow" && git push origin main
```
The new `build-linux-runners.yml` workflow will build and push all 4 images automatically.

**Option B — Local build:**
```bash
export GITHUB_TOKEN=<your-PAT>
./build-and-push.sh --push
```

### Step 3 — Restart EC2 Runner Containers
```bash
# SSH into the instance (key: github-runner-key, region: eu-north-1)
ssh -i ~/.ssh/github-runner-key ubuntu@16.170.98.124

# On the instance:
docker ps -a --filter "name=runner-"   # see crashed containers
docker rm -f $(docker ps -aq --filter "name=runner-")  # remove all
/usr/local/bin/start-runners.sh        # re-spawn fresh containers
```

### Step 4 — Verify Runner Registration
Go to GitHub → your org → Settings → Actions → Runners. Runners should appear as **Online** within ~30 seconds of container start.