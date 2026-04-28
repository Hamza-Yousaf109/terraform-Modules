data "aws_ami" "ubuntu" {
  most_recent = true

  owners = ["099720109477"]

  filter {
    name   = "name"
    values = ["ubuntu/images/hvm-ssd/ubuntu-jammy-22.04-amd64-server-*"]
  }

  filter {
    name   = "virtualization-type"
    values = ["hvm"]
  }
}

resource "aws_security_group" "default" {
  count  = var.vpc_id != "" ? 1 : 0
  vpc_id = var.vpc_id
  name   = "${var.name_prefix}-sg"

  ingress {
    from_port   = 0
    to_port     = 65535
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = {
    Name = "${var.name_prefix}-sg"
  }
}

resource "aws_instance" "app" {
  count           = var.instance_count
  ami             = data.aws_ami.ubuntu.id
  instance_type   = var.instance_type
  key_name        = var.key_name
  subnet_id       = var.subnet_id != "" ? var.subnet_id : null
  vpc_security_group_ids = var.vpc_id != "" ? [aws_security_group.default[0].id] : null

  tags = {
    Name = "${var.name_prefix}-${count.index + 1}"
  }
}