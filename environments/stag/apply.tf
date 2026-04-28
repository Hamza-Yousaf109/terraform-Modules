module "ec2" {
  source = "../../module/ec2"

  instance_count = "1"
  instance_type  = "t3.large"
  key_name       = "devops"
  name_prefix    = "test"
}

module "s3" {
  source = "../../module/s3"
  bucket_name = "hamziii-stag"
  environment = "dev"
}