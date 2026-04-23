# =============================================================================
# terraform.tfvars — fill in your values here
# Copy this to terraform.tfvars and edit before running terraform apply
# =============================================================================

# TODO: Your GitHub test org name
github_org = "py-libp2p-runners"

# TODO: Update after you push image to GHCR
# Format: ghcr.io/<github-username-or-org>/runner-py-libp2p:latest
ghcr_image = "ghcr.io/py-libp2p-runners/runner-py-libp2p:linux-latest"

# These are already set to correct defaults — change only if needed
aws_region           = "eu-north-1"
ssm_pat_path         = "/github-runners/pat"
runner_labels        = "self-hosted,linux,x64,python"
runners_per_instance = 2
instance_type        = "t3.medium"
instance_count       = 1
key_pair_name        = "ec2-runner"
