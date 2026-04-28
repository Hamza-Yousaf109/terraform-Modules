output "instance_ids" {
  description = "List of EC2 instance IDs"
  value       = aws_instance.app[*].id
}

output "private_ips" {
  description = "List of EC2 instance private IPs"
  value       = aws_instance.app[*].private_ip
}

output "public_ips" {
  description = "List of EC2 instance public IPs"
  value       = aws_instance.app[*].public_ip
}

output "ami_id" {
  description = "AMI ID used for instances"
  value       = data.aws_ami.ubuntu.id
}

output "security_group_id" {
  description = "Security group ID for instances"
  value       = try(aws_security_group.default[0].id, null)
}
