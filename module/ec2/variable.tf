variable "instance_count" {
    description = "number of instances "
    type = number
}
variable "instance_type" {
    description = "instance type "
    type = string
}
variable "key_name" {
    description = "key name "
    type = string
}
variable "name_prefix" {
    description = "instance name"
    type = string
}
variable "vpc_id" {
    description = "VPC ID"
    type = string
    default = ""
}
variable "subnet_id" {
    description = "Subnet ID for instance placement"
    type = string
    default = ""
}
