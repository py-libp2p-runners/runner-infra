# =============================================================================
# outputs.tf — useful values after terraform apply
# =============================================================================

output "ec2_instance_ids" {
  description = "EC2 instance IDs — use these to SSH in for debugging"
  value       = aws_instance.runner[*].id
}

output "ec2_public_ips" {
  description = "Public IPs of runner instances (if in default VPC)"
  value       = aws_instance.runner[*].public_ip
}

output "runner_labels" {
  description = "Labels to use in workflow runs-on field"
  value       = "runs-on: [${var.runner_labels}]"
}

output "debug_commands" {
  description = "Useful commands for debugging after apply"
  value = {
    check_user_data_log  = "ssh ubuntu@<EC2_IP> 'cat /var/log/user-data.log'"
    check_runner_refill  = "ssh ubuntu@<EC2_IP> 'cat /var/log/runner-refill.log'"
    list_containers      = "ssh ubuntu@<EC2_IP> 'docker ps'"
    container_logs       = "ssh ubuntu@<EC2_IP> 'docker logs runner-<NAME>'"
  }
}
