terraform {
  backend "s3" {
    bucket = "hamziii"
    key    = "prod/ec2/terraform.tfstate"
    region = "ca-central-1"
    encrypt = true
  }
}
