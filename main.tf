provider "aws" {
    region = var.aws_region
}

data "aws_availability_zones" "available" {}

data "aws_ami" "ubuntu" {
  most_recent = true

  filter {
    name   = "name"
    values = ["ubuntu/images/hvm-ssd/ubuntu-xenial-16.04-amd64-server-*"]
  }

  filter {
    name   = "virtualization-type"
    values = ["hvm"]
  }

  owners = ["099720109477"] # Canonical
}

data "aws_ami" "nat_instance" {
  most_recent = true

  filter {
    name   = "name"
    values = ["amzn-ami-vpc-nat-hvm-*"]
  }

  filter {
    name   = "virtualization-type"
    values = ["hvm"]
  }

  owners = ["137112412989"] # Amazon
}

# VPC 

resource "aws_vpc" "hashicorp_vpc" {
  cidr_block           = var.network_address_space
  enable_dns_hostnames = "true"

  tags = {
    Name        = "${var.name}-vpc"
    TTL         = var.ttl
    Owner       = var.owner
  }
}

# Internet Gateways and route table

resource "aws_internet_gateway" "igw" {
  vpc_id = aws_vpc.hashicorp_vpc.id
}

resource "aws_route_table" "rtb" {
  vpc_id = aws_vpc.hashicorp_vpc.id

  route {
    cidr_block = "0.0.0.0/0"
    gateway_id = aws_internet_gateway.igw.id
  }

  tags = {
    Name        = "${var.name}-igw"
  }
}

# nat route table

resource "aws_route_table" "rtb-nat" {
  vpc_id = aws_vpc.hashicorp_vpc.id

  route {
    cidr_block  = "0.0.0.0/0"
    instance_id = aws_instance.nat.id
  }

  tags = {
    Name        = "${var.name}-nat_instance"
  }
}

# public subnet to IGW

resource "aws_route_table_association" "dmz-subnet" {
  subnet_id      = aws_subnet.dmz_subnet.*.id[0]
  route_table_id = aws_route_table.rtb.id
}

# limit the amout of public web subnets to the amount of AZ
resource "aws_route_table_association" "pub_web-subnet" {
  count          = local.mod_az
  subnet_id      = element(aws_subnet.pub_web_subnet.*.id, count.index)
  route_table_id = aws_route_table.rtb.id
}

# private subnet to NAT

resource "aws_route_table_association" "rtb-web" {
  count          = var.web_subnet_count
  subnet_id      = element(aws_subnet.web_subnet.*.id, count.index)
  route_table_id = aws_route_table.rtb-nat.id
}

# subnet public

resource "aws_subnet" "dmz_subnet" {
  vpc_id                  = aws_vpc.hashicorp_vpc.id
  cidr_block              = cidrsubnet(var.network_address_space, 8, 1)
  map_public_ip_on_launch = "true"
  availability_zone       = data.aws_availability_zones.available.names[0]

  tags = {
    Name        = "dmz-subnet"
  }
}

resource "aws_subnet" "pub_web_subnet" {
  count                   = local.mod_az
  cidr_block              = cidrsubnet(var.network_address_space, 8, count.index + 10)
  vpc_id                  = aws_vpc.hashicorp_vpc.id
  map_public_ip_on_launch = "true"
  availability_zone       = data.aws_availability_zones.available.names[count.index % local.mod_az]

  tags = {
    Name        = "web-pub-subnet"
  }
}

# subnet private

resource "aws_subnet" "web_subnet" {
  count                   = var.web_subnet_count
  cidr_block              = cidrsubnet(var.network_address_space, 8, count.index + 20)
  vpc_id                  = aws_vpc.hashicorp_vpc.id
  map_public_ip_on_launch = "false"

  availability_zone       = data.aws_availability_zones.available.names[count.index % local.mod_az]

  tags = {
    Name        = "web-prv-subnet"
  }
}

resource "aws_instance" "nat" {
  ami                         = data.aws_ami.nat_instance.id
  instance_type               = "t2.micro"
  subnet_id                   = aws_subnet.dmz_subnet.id
  associate_public_ip_address = "true"
  vpc_security_group_ids      = [aws_security_group.nat.id]
  key_name                    = var.key_name
  source_dest_check           = false

  tags = {
    Name        = "nat-instance"
    TTL         = var.ttl
    Owner       = var.owner
  }
}

# LOAD BALANCER #
resource "aws_elb" "web-elb" {
  name = "web-elb"

  tags = {
    Name        = "web-elb"
    TTL         = var.ttl
    Owner       = var.owner
  }

  subnets         = aws_subnet.pub_web_subnet.*.id
  security_groups = [aws_security_group.elb.id]
  instances       = aws_instance.web_nodes.*.id

  listener {
    instance_port     = 80
    instance_protocol = "http"
    lb_port           = 80
    lb_protocol       = "http"
  }
}

resource "aws_route53_record" "elb" {
  zone_id = data.aws_route53_zone.selected.zone_id
  name    = "${var.name}.data.aws_route53_zone.selected.name"
  type    = "CNAME"
  ttl     = "300"
  records = [aws_elb.web-elb.dns_name]
}

# INSTANCES

resource "aws_instance" "jumphost" {
  ami                         = data.aws_ami.ubuntu.id
  instance_type               = "t2.micro"
  subnet_id                   = aws_subnet.dmz_subnet.id
  private_ip                  = cidrhost(aws_subnet.dmz_subnet.cidr_block, 10)
  associate_public_ip_address = "true"
  vpc_security_group_ids      = [aws_security_group.jumphost.id]
  key_name                    = var.key_name

  user_data = <<-EOF
              #!/bin/bash
              echo "${var.id_rsa_aws}" >> /home/ubuntu/.ssh/id_rsa
              chown ubuntu /home/ubuntu/.ssh/id_rsa
              chgrp ubuntu /home/ubuntu/.ssh/id_rsa
              chmod 600 /home/ubuntu/.ssh/id_rsa
              apt-get update -y
              apt-get install ansible -y 
              EOF

  tags = {
    Name        = "jumphost-${var.name}"
    TTL         = var.ttl
    Owner       = var.owner             
  }
}

# DNS

data "aws_route53_zone" "selected" {
  name         = "${var.dns_domain}."
  private_zone = false
}

resource "aws_route53_record" "jumphost" {
  zone_id = data.aws_route53_zone.selected.zone_id
  name    = lookup(aws_instance.jumphost.*.tags[0], "Name")

  #name    = "jumphost"
  type    = "A"
  ttl     = "300"
  records = [aws_instance.jumphost.public_ip]
}

resource "aws_instance" "web_nodes" {
  count                       = var.web_node_count
  ami                         = data.aws_ami.ubuntu.id
  instance_type               = var.instance_type
  subnet_id                   = element(aws_subnet.web_subnet.*.id, count.index + 1)
  associate_public_ip_address = "false"
  vpc_security_group_ids      = [aws_security_group.web.id]
  key_name                    = var.key_name

  tags = {
    Name        = format("web-%02d", count.index + 1)
    TTL         = var.ttl
    Owner       = var.owner
  }
}

resource "aws_key_pair" "joestack_aws" {
  key_name   = "joestack_aws"
  public_key = "ssh-rsa AAAAB3NzaC1yc2EAAAADAQABAAABAQCvOp4xxCMWtSfMkO73Xv29aavZlPKFdJ3kI9CpY1Dnl0Q945TybNcFQuZ53RRvw7ccOx0CctuzDRwW3FX9rdD96htu2uoZXeeY0tB2gb3md/LpKw3I+PRJXIHwwbfpQK8rxXlmDIiPR8P7frNs/Y3z2dYxlmlE+OB4Y3hbF10vBxJUECX2AmTNDb+IBS1APJc/Sw+04aEwh2kiv5tfqhM+1bjhKxBzY/h5+H7jV0psH/TeAkr7yvY7KVwrqad+MXGvMfAwp0ziWh7BWMUeOHsCIJx9tUlLPL/5HvjeFniALXVIIrGo/kz1SI0Q5Na60iAETi1t8jlWOOPOWLe28JUL joern@Think-X1"
}

