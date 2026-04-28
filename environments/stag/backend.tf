terraform {
  backend "s3" {
    bucket         = "hamziii"
    key            = "stag/ec2/terraform.tfstate"
    region         = "ca-central-1"
    use_lockfile   = true
    encrypt        = true
  }
}
