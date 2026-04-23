# =============================================================================
# windows-runners.tf — Windows EC2 instances for GitHub Actions self-hosted runners
# =============================================================================

# Windows runners should be deployed separately from Linux runners
# Uncomment and adjust as needed for your Windows runner deployment

# data "aws_ami" "windows" {
#   most_recent = true
#   owners      = ["amazon"]
#
#   filter {
#     name   = "name"
#     values = ["Windows_Server-2022-English-Core-*"]
#   }
#
#   filter {
#     name   = "virtualization-type"
#     values = ["hvm"]
#   }
# }

# resource "aws_instance" "windows_runner" {
#   count = var.windows_instance_count
#
#   ami                  = data.aws_ami.windows.id
#   instance_type        = var.windows_instance_type  # m5.xlarge recommended for Windows
#   iam_instance_profile = aws_iam_instance_profile.runner.name
#   vpc_security_group_ids = [aws_security_group.runner.id]
#   key_name             = var.key_pair_name != "" ? var.key_pair_name : null
#
#   user_data = templatefile("${path.module}/windows_user_data.ps1", {
#     github_org           = var.github_org
#     ssm_pat_path         = var.ssm_pat_path
#     ghcr_image           = var.ghcr_image_windows
#     runner_labels        = var.windows_runner_labels
#     runners_per_instance = var.runners_per_instance
#     aws_region           = var.aws_region
#   })
#
#   metadata_options {
#     http_endpoint               = "enabled"
#     http_protocol_ipv6          = "disabled"
#     http_put_response_hop_limit = 2
#     http_tokens                 = "required"
#   }
#
#   root_block_device {
#     volume_type           = "gp3"
#     volume_size           = 100  # Windows needs more space
#     delete_on_termination = true
#     encrypted             = true
#   }
#
#   tags = merge(local.common_tags, {
#     Name = "github-runner-windows-${count.index + 1}"
#   })
# }
