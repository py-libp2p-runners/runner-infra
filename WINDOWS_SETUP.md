# Windows GitHub Actions Self-Hosted Runners — Setup Guide

## Step 1 — Build and push the Windows Docker image

```bash
# Build for Windows (requires Docker Desktop with Windows containers enabled)
docker build --platform windows/amd64 -f Dockerfile.windows -t ghcr.io/py-libp2p-runners/runner-py-libp2p-windows:latest .

# Push to GHCR
docker push ghcr.io/py-libp2p-runners/runner-py-libp2p-windows:latest
```

Make the package public in GitHub if needed:
→ github.com/py-libp2p-runners → Packages → runner-py-libp2p-windows → Package settings → Make public

---

## Step 2 — Configure Terraform for Windows runners

Edit your `terraform.tfvars` and add:

```hcl
# Windows runners
ghcr_image_windows     = "ghcr.io/py-libp2p-runners/runner-py-libp2p-windows:latest"
windows_instance_count = 1  # or more
windows_instance_type  = "m5.xlarge"  # Windows needs more resources
windows_runner_labels  = "self-hosted,windows,x64"
```

---

## Step 3 — Uncomment the Windows configuration in Terraform

Edit `windows-runners.tf` and uncomment all the resource blocks and data source.

Also uncomment in `main.tf` if needed for the Windows security group / IAM role sharing.

---

## Step 4 — Deploy Windows runners

```bash
terraform plan
terraform apply
```

This will launch Windows EC2 instances and bootstrap them with Docker + GitHub runners.

---

## Step 5 — Verify Windows runners registered

After ~5-10 minutes (Windows takes longer to boot):
→ github.com/organizations/py-libp2p-runners/settings/actions/runners

You should see Windows runners with labels: `self-hosted`, `windows`, `x64`

---

## Step 6 — Update workflow to use Windows runners

In your `.github/workflows/tox.yml`:

```yaml
  windows:
    runs-on: [self-hosted, windows, x64]  # or use ec2 label if you prefer
    timeout-minutes: 60
    strategy:
      matrix:
        python-version: ["3.11", "3.12", "3.13"]
        toxenv: [core, demos, utils, wheel]
    steps:
      # ... your jobs ...
```

---

## Notes

- **Instance size**: Windows runners need at least `m5.xlarge` (2 vCPU, 8GB RAM). `t3.medium` is too small.
- **Volume size**: Windows requires more disk space. The template defaults to 100GB.
- **Boot time**: Windows instances take 5-10 minutes to boot, unlike Linux's 1-2 minutes.
- **Costs**: Windows instances are more expensive than Linux. Budget accordingly.
- **Multiple Python versions**: The Dockerfile installs Python 3.11, 3.12, 3.13 via Chocolatey.

---

## Troubleshooting

**Runners not appearing:**
- SSH into the instance (RDP if Windows): check `C:\logs\windows-user-data.log`
- Verify the PAT has correct scopes (`repo`, `admin:org_hook`)
- Check Docker daemon is running: `docker ps`

**Jobs not picked up:**
- Verify runner group allows repository access (Settings → Actions → Runner groups → Default → All repositories)
- Confirm labels match exactly (case-sensitive on some systems)

**Build failures:**
- Check `C:\runners\*\log.txt` in the runner work directory
- Verify all required build tools are installed (Visual Studio workload, NASM, etc.)
