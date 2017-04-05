variable "aws_access_key" {}

variable "aws_secret_key" {}

variable "aws_region" {
  default = "us-west-2"
}

provider "aws" {
  access_key = "${var.aws_access_key}"
  secret_key = "${var.aws_secret_key}"
  region     = "${var.aws_region}"
}

# SSH connectivity (KeyPair)
data "template_file" "key" {
  template = "${file("./keys/api.pub")}"
}

resource "aws_key_pair" "api" {
  key_name   = "api_ssh_key"
  public_key = "${data.template_file.key.rendered}"
}

# VPC
resource "aws_vpc" "api" {
  cidr_block           = "10.0.0.0/16"
  enable_dns_hostnames = true
  enable_dns_support   = true
  instance_tenancy     = "default"
}

# VPC Security Group (Allow SSH/HTTP) - Statefull
resource "aws_security_group" "api-allow-ssh" {
  name   = "api"
  vpc_id = "${aws_vpc.api.id}"

  ingress {
    from_port   = 22
    to_port     = 22
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  ingress {
    from_port   = 80
    to_port     = 80
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }
}

# Internet GW for creating public connectivity
resource "aws_internet_gateway" "api-igw" {
  vpc_id = "${aws_vpc.api.id}"

  tags {
    Name = "Managed by Terraform"
  }
}

# Route table to associate with VPC
resource "aws_route_table" "api" {
  vpc_id = "${aws_vpc.api.id}"

  tags {
    Name      = "api-rt"
    ManagedBy = "terraform"
  }
}

# Route to allow public access
resource "aws_route" "to_gateway" {
  route_table_id         = "${aws_route_table.api.id}"
  destination_cidr_block = "0.0.0.0/0"
  gateway_id             = "${aws_internet_gateway.api-igw.id}"
}

# Route table to VPC association
resource "aws_main_route_table_association" "api" {
  vpc_id         = "${aws_vpc.api.id}"
  route_table_id = "${aws_route_table.api.id}"
}

# Create a subnet
resource "aws_subnet" "api-a" {
  cidr_block        = "10.0.1.0/24"
  vpc_id            = "${aws_vpc.api.id}"
  availability_zone = "${var.aws_region}a"
}

data "template_file" "init" {
  template = "${file("scripts/userdata.sh")}"

  vars {
    WEBSERVER_MESSAGE = "Hello AWS World"
  }
}

# EC2 Instance - API initiated with the userdata above
resource "aws_instance" "api" {
  ami                    = "ami-9d34a0fd"
  instance_type          = "t2.micro"
  key_name               = "${aws_key_pair.api.key_name}"
  vpc_security_group_ids = ["${aws_security_group.api-allow-ssh.id}"]
  subnet_id              = "${aws_subnet.api-a.id}"
  tenancy                = "default"
  user_data              = "${data.template_file.init.rendered}"

  root_block_device {
    delete_on_termination = true
    volume_size           = 20
    volume_type           = "gp2"
  }

  ebs_block_device {
    device_name           = "/dev/xvdb"
    delete_on_termination = true
    volume_size           = 1
    volume_type           = "gp2"
  }
}

# Elastic IP assigned to the EC2 instance api
resource "aws_eip" "api" {
  instance = "${aws_instance.api.id}"
  vpc      = true
}
