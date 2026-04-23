# GitHub Actions Self-Hosted Runners — Setup Guide

## Directory structure

```
tf-github-runners/
├── main.tf                    # EC2, IAM, Security Group
├── variables.tf               # All configurable inputs
├── outputs.tf                 # Useful values after apply
├── terraform.tfvars.example   # Copy this to terraform.tfvars and fill in
└── scripts/
    └── user_data.sh.tpl       # Runs on EC2 boot — starts runner containers
```

---

## Step 1 — Build and push the Docker image to GHCR

Do this BEFORE running Terraform, EC2 needs to pull the image.

```bash
# Login to GHCR
echo $GITHUB_PAT | docker login ghcr.io -u py-libp2p-runners --password-stdin

# Build
cd runner-py-libp2p/
docker build -t ghcr.io/py-libp2p-runners/runner-py-libp2p:latest .

# Push
docker push ghcr.io/py-libp2p-runners/runner-py-libp2p:latest
```

Make the package public in GitHub:
→ github.com/YOUR_USERNAME → Packages → runner-py-libp2p → Package settings → Make public
(Or keep private and ensure your PAT has `read:packages` scope)

---

## Step 2 — Configure Terraform variables

```bash
cp terraform.tfvars.example terraform.tfvars
```

Edit `terraform.tfvars`:
- Set `github_org` to your test org name
- Set `ghcr_image` to the image you pushed in Step 1

---

## Step 3 — Run Terraform

```bash
terraform init
terraform plan    # review what will be created
terraform apply   # type 'yes' to confirm
```

This creates:
- IAM role with SSM read permission
- Security group (outbound HTTPS only)
- EC2 instance (Ubuntu 22.04, t3.medium)
- user_data bootstraps Docker + starts 2 runner containers

---

## Step 4 — Verify runners registered

After ~3 minutes:
→ github.com/organizations/py-libp2p-runners/settings/actions/runners

You should see 2 runners with status "Idle".

If they don't appear, SSH into EC2 and check:
```bash
# Check bootstrap log
cat /var/log/user-data.log

# Check running containers
docker ps

# Check a specific container's logs
docker logs runner-<name>
```

---

## Step 5 — Update py-libp2p workflow to use self-hosted runners

In `.github/workflows/` of your test py-libp2p repo, change:

```yaml
# Before
runs-on: ubuntu-latest

# After
runs-on: [self-hosted, linux, x64, python]
```

Push the change and watch the job appear in:
→ github.com/organizations/YOUR_TEST_ORG/settings/actions/runners

---

## Step 6 — Trigger a test run

```bash
# Push any small change to trigger CI
git commit --allow-empty -m "test: trigger self-hosted runner"
git push
```

Watch the Actions tab — job should be picked up by your runner within seconds.

---

## Teardown

```bash
terraform destroy   # removes all AWS resources
```

Runners deregister automatically when containers stop (EPHEMERAL=true).
