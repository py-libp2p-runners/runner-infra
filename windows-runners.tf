# =============================================================================
# windows-runners.tf — Windows EC2 instances for GitHub Actions self-hosted runners
#
# Uses Windows Server 2022 with Containers feature + Docker Engine (not Desktop).
# Set windows_instance_count = 1 in terraform.tfvars to enable.
# =============================================================================

data "aws_ami" "windows" {
  most_recent = true
  owners      = ["amazon"]

  filter {
    name   = "name"
    # Full Windows Server 2022 (not Core) — needed for Docker + GUI tools
    values = ["Windows_Server-2022-English-Full-Base-*"]
  }

  filter {
    name   = "virtualization-type"
    values = ["hvm"]
  }
}

resource "aws_instance" "windows_runner" {
  count = var.windows_instance_count

  ami                    = data.aws_ami.windows.id
  instance_type          = var.windows_instance_type
  iam_instance_profile   = aws_iam_instance_profile.runner.name
  vpc_security_group_ids = [aws_security_group.runner.id]
  key_name               = var.key_pair_name != "" ? var.key_pair_name : null

  # EC2 Launch v2 on Windows handles <powershell> tags natively — no base64 needed
  user_data = templatefile("${path.module}/windows_user_data.ps1", {
    github_org           = var.github_org
    ssm_pat_path         = var.ssm_pat_path
    ghcr_image           = var.ghcr_image_windows
    runner_labels        = var.windows_runner_labels
    runners_per_instance = var.runners_per_instance
    aws_region           = var.aws_region
  })

  metadata_options {
    http_endpoint               = "enabled"
    http_protocol_ipv6          = "disabled"
    http_put_response_hop_limit = 2
    http_tokens                 = "required"
  }

  root_block_device {
    volume_type           = "gp3"
    volume_size           = 100  # Windows + Docker images need space
    delete_on_termination = true
    encrypted             = true
  }

  tags = merge(local.common_tags, {
    Name = "github-runner-windows-${count.index + 1}"
    OS   = "windows"
  })
}

output "windows_runner_public_ips" {
  description = "Public IPs of Windows runner instances"
  value       = aws_instance.windows_runner[*].public_ip
}
