output "instances_with_ssh" {
  description = "EC2 instances with SSH connection details for Ansible"
  value       = module.ec2.instances_with_ssh
}

output "instance_ids" {
  description = "EC2 instance IDs"
  value       = module.ec2.instance_ids
}

output "public_ips" {
  description = "Public IP addresses of EC2 instances"
  value       = module.ec2.public_ips
}

output "private_ips" {
  description = "Private IP addresses of EC2 instances"
  value       = module.ec2.private_ips
}

output "vpc_id" {
  description = "VPC ID"
  value       = module.vpc.vpc_id
}

output "s3_bucket_name" {
  description = "S3 bucket name"
  value       = module.s3.bucket_name
}
