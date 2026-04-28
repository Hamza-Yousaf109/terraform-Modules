module "ec2" {
  source = "../../module/ec2"

  instance_count         = 1
  instance_type          = "t3.large"
  key_name               = "devops"
  name_prefix            = "test"
  vpc_id                 = module.vpc.vpc_id
  subnet_id              = module.vpc.subnet_id
  create_security_group  = true
  depends_on             = [module.vpc]
}

module "s3" {
  source = "../../module/s3"
  bucket_name = "hamziii-stag"
  environment = "stag"
}

module "vpc" {
  source = "../../module/vpc"

  vpc_name           = "stag-vpc"
  vpc_cidr           = "10.1.0.0/24"
  subnet_cidr        = "10.1.0.0/25"
  availability_zone  = "us-east-1a"
  map_public_ip      = true
  environment        = "stag"
}