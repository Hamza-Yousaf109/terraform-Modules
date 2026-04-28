output "vpc_id" {
  description = "The ID of the VPC"
  value       = aws_vpc.main.id
}

output "vpc_cidr" {
  description = "The CIDR block of the VPC"
  value       = aws_vpc.main.cidr_block
}

output "subnet_id" {
  description = "The ID of the subnet"
  value       = aws_subnet.main.id
}

output "subnet_cidr" {
  description = "The CIDR block of the subnet"
  value       = aws_subnet.main.cidr_block
}

output "igw_id" {
  description = "The ID of the Internet Gateway"
  value       = aws_internet_gateway.main.id
}

output "route_table_id" {
  description = "The ID of the route table"
  value       = aws_route_table.main.id
}

output "availability_zone" {
  description = "The availability zone of the subnet"
  value       = aws_subnet.main.availability_zone
}
