# =============================================================================
# variables.tf — fill these in before running terraform apply
# =============================================================================

variable "github_org" {
  description = "Your GitHub org name (e.g. my-test-org)"
  type        = string
  # TODO: set this to your org name
  # Either set it here or pass via: terraform apply -var="github_org=my-test-org"
}

variable "aws_region" {
  description = "AWS region"
  type        = string
  default     = "ap-south-1"
}

variable "ssm_pat_path" {
  description = "SSM parameter path where GitHub PAT is stored"
  type        = string
  default     = "/github-runners/pat"
}

variable "ghcr_image" {
  description = "Full GHCR image path for the runner"
  type        = string
  # e.g. ghcr.io/your-org/runner-py-libp2p:latest
  # TODO: update after you push the image to GHCR
  default     = "ghcr.io/YOUR_ORG/runner-py-libp2p:latest"
}

variable "runner_labels" {
  description = "Comma-separated labels for GitHub Actions runs-on targeting"
  type        = string
  default     = "self-hosted,linux,x64,python"
}

variable "runners_per_instance" {
  description = "Number of runner containers to start per EC2 instance"
  type        = number
  default     = 2  # safe default for t3.medium — bump up for larger instances
}

variable "instance_type" {
  description = "EC2 instance type"
  type        = string
  default     = "t3.medium"  # 2 vCPU, 4GB — good for 2 runners
}

variable "instance_count" {
  description = "Number of EC2 instances to launch"
  type        = number
  default     = 1  # start with 1 for testing
}

variable "key_pair_name" {
  description = "EC2 key pair name for SSH access"
  type        = string
  default     = ""
}

variable "ghcr_image_windows" {
  description = "Full GHCR image path for Windows runners"
  type        = string
  default     = ""
}

variable "windows_runner_labels" {
  description = "Comma-separated labels for Windows runners"
  type        = string
  default     = "self-hosted,windows,x64"
}

variable "windows_instance_type" {
  description = "EC2 instance type for Windows runners"
  type        = string
  default     = "m5.xlarge"  # Windows needs more resources
}

variable "windows_instance_count" {
  description = "Number of Windows EC2 instances to launch"
  type        = number
  default     = 0  # Disabled by default — set to 1+ to enable
}
