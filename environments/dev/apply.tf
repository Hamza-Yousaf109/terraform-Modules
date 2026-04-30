module "ec2" {
  source = "../../module/ec2"

  instance_count         = "1"
  instance_type          = "t3.medium"
  key_name               = "devops"
  name_prefix            = "test"
  vpc_id                 = module.vpc.vpc_id
  subnet_id              = module.vpc.subnet_id
  create_security_group  = true
  depends_on             = [module.vpc]
}

module "s3" {
  source = "../../module/s3"
  bucket_name = "hamziii-dev"
  environment = "dev"
}

module "vpc" {
  source = "../../module/vpc"

  vpc_name           = "dev-vpc"
  vpc_cidr           = "10.0.0.0/24"
  subnet_cidr        = "10.0.0.0/25"
  availability_zone  = "us-east-1a"
  map_public_ip      = true
  environment        = "dev"
}


