module "ec2" {
  source = "../../module/ec2"

  instance_count         = 2
  instance_type          = "t3.large"
  key_name               = "devops"
  name_prefix            = "prod"
  vpc_id                 = module.vpc.vpc_id
  subnet_id              = module.vpc.subnet_id
  create_security_group  = true
  depends_on             = [module.vpc]
}

module "s3" {
  source = "../../module/s3"
  bucket_name = "hamziii-prod"
  environment = "prod"
}

module "vpc" {
  source = "../../module/vpc"

  vpc_name           = "prod-vpc"
  vpc_cidr           = "10.2.0.0/24"
  subnet_cidr        = "10.2.0.0/25"
  availability_zone  = "us-east-1a"
  map_public_ip      = true
  environment        = "prod"
}
