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

output "instance_details" {
  description = "Detailed instance information for Ansible inventory generation"
  value = [
    for instance in aws_instance.app : {
      instance_id    = instance.id
      instance_name  = instance.tags.Name
      public_ip      = instance.public_ip
      private_ip     = instance.private_ip
      instance_type  = instance.instance_type
      availability_zone = instance.availability_zone
      subnet_id      = instance.subnet_id
    }
  ]
}

output "instances_with_ssh" {
  description = "Instance data structured for Ansible inventory with SSH connectivity details"
  value = {
    instances = [
      for instance in aws_instance.app : {
        name           = instance.tags.Name
        ansible_host   = instance.public_ip
        ansible_user   = "ubuntu"
        private_ip     = instance.private_ip
        instance_id    = instance.id
        availability_zone = instance.availability_zone
      }
    ]
    security_group_id = try(aws_security_group.default[0].id, null)
    key_name          = var.key_name
  }
}

output "ami_id" {
  description = "AMI ID used for instances"
  value       = data.aws_ami.ubuntu.id
}

output "security_group_id" {
  description = "Security group ID for instances"
  value       = try(aws_security_group.default[0].id, null)
}
