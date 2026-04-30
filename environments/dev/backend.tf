terraform {
  backend "s3" {
    bucket         = "hamziii"
    key            = "dev/ec2/terraform.tfstate"
    region         = "ca-central-1"
    dynamodb_table = "terraform-locks"
    encrypt        = true
  }
}
