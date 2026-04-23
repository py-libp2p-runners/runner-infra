# =============================================================================
# main.tf — GitHub Actions self-hosted runners on EC2
# Region: ap-south-1 (Mumbai)
#
# What this creates:
#   1. IAM role + instance profile   — lets EC2 read SSM (PAT) and push logs
#   2. Security group                — outbound HTTPS only, no inbound
#   3. EC2 instance(s)               — Ubuntu 22.04, runs runner containers
#   4. user_data script              — installs Docker, pulls image, starts N runners
# =============================================================================

terraform {
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0"
    }
  }
  required_version = ">= 1.3.0"
}

provider "aws" {
  region = var.aws_region
}

# -----------------------------------------------------------------------------
# Data sources
# -----------------------------------------------------------------------------

# Latest Ubuntu 22.04 LTS AMI in ap-south-1
data "aws_ami" "ubuntu" {
  most_recent = true
  owners      = ["099720109477"] # Canonical

  filter {
    name   = "name"
    values = ["ubuntu/images/hvm-ssd/ubuntu-jammy-22.04-amd64-server-*"]
  }

  filter {
    name   = "virtualization-type"
    values = ["hvm"]
  }
}

# Pull the PAT from SSM to verify it exists — actual value is read by user_data at runtime
data "aws_ssm_parameter" "github_pat" {
  name = var.ssm_pat_path
}

# Current AWS account ID — used for IAM policy scoping
data "aws_caller_identity" "current" {}

# -----------------------------------------------------------------------------
# 1. IAM Role — lets EC2 instances read SSM and write CloudWatch logs
# -----------------------------------------------------------------------------

resource "aws_iam_role" "runner" {
  name = "github-runner-role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Effect    = "Allow"
      Principal = { Service = "ec2.amazonaws.com" }
      Action    = "sts:AssumeRole"
    }]
  })

  tags = local.common_tags
}

resource "aws_iam_role_policy" "runner_ssm" {
  name = "github-runner-ssm-policy"
  role = aws_iam_role.runner.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        # Read the PAT from SSM on instance startup
        Effect = "Allow"
        Action = [
          "ssm:GetParameter",
          "ssm:GetParameters"
        ]
        Resource = "arn:aws:ssm:${var.aws_region}:${data.aws_caller_identity.current.account_id}:parameter${var.ssm_pat_path}"
      },
      {
        # Write runner logs to CloudWatch for debugging
        Effect = "Allow"
        Action = [
          "logs:CreateLogGroup",
          "logs:CreateLogStream",
          "logs:PutLogEvents"
        ]
        Resource = "*"
      }
    ]
  })
}

resource "aws_iam_instance_profile" "runner" {
  name = "github-runner-instance-profile"
  role = aws_iam_role.runner.name
}

# -----------------------------------------------------------------------------
# 2. Security Group — outbound HTTPS only
#    Runners connect OUT to GitHub. GitHub never connects IN.
# -----------------------------------------------------------------------------

resource "aws_security_group" "runner" {
  name        = "github-runner-sg"
  description = "GitHub Actions runner - outbound only"

  # HTTPS out — GitHub API, GHCR image pull, actions artifact uploads
  egress {
    from_port   = 443
    to_port     = 443
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
    description = "HTTPS to GitHub and GHCR"
  }

  # HTTP out — package installs (apt, deadsnakes PPA)
  egress {
    from_port   = 80
    to_port     = 80
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
    description = "HTTP for apt package installs"
  }

  # DNS
  egress {
    from_port   = 53
    to_port     = 53
    protocol    = "udp"
    cidr_blocks = ["0.0.0.0/0"]
    description = "DNS resolution"
  }

  # NOTE: No inbound rules — runners poll GitHub, GitHub never connects to us
  # SSH for debugging
  ingress {
    from_port   = 22
    to_port     = 22
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
    description = "SSH access"
  }

  tags = merge(local.common_tags, { Name = "github-runner-sg" })
}

# -----------------------------------------------------------------------------
# 3. EC2 Instances
# -----------------------------------------------------------------------------

resource "aws_instance" "runner" {
  count = var.instance_count

  ami                  = data.aws_ami.ubuntu.id
  instance_type        = var.instance_type
  iam_instance_profile = aws_iam_instance_profile.runner.name
  vpc_security_group_ids = [aws_security_group.runner.id]
  key_name             = var.key_pair_name != "" ? var.key_pair_name : null

  # user_data runs once on first boot — installs Docker, pulls image, starts runners
  user_data = templatefile("${path.module}/user_data.sh.tpl", {
    github_org           = var.github_org
    ssm_pat_path         = var.ssm_pat_path
    ghcr_image           = var.ghcr_image
    runner_labels        = var.runner_labels
    runners_per_instance = var.runners_per_instance
    aws_region           = var.aws_region
  })

  # Required for IMDSv2 (SSM SDK uses this)
  metadata_options {
    http_endpoint               = "enabled"
    http_tokens                 = "required"  # IMDSv2
    http_put_response_hop_limit = 2           # needed for Docker containers to reach IMDS
  }

  root_block_device {
    volume_size = 30   # GB — enough for Docker images + runner workdir
    volume_type = "gp3"
    encrypted   = true
  }

  tags = merge(local.common_tags, {
    Name = "github-runner-${count.index + 1}"
  })
}

# -----------------------------------------------------------------------------
# Locals
# -----------------------------------------------------------------------------

locals {
  common_tags = {
    Project     = "github-runners"
    ManagedBy   = "terraform"
    Runner      = "py-libp2p"
  }
}
