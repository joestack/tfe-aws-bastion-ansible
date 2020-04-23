terraform {
  required_version = ">= 0.12"
}

provider "aws" {
    region = var.aws_region
    version = "=2.55.0"
}

resource "aws_key_pair" "joestack_aws" {
  key_name   = "joestack_aws"
  public_key = var.pub_key
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

# Network & Routing
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


# DNS

data "aws_route53_zone" "selected" {
  name         = "${var.dns_domain}."
  private_zone = false
}

resource "aws_route53_record" "bastionhost" {
  zone_id = data.aws_route53_zone.selected.zone_id
  name    = lookup(aws_instance.bastionhost.*.tags[0], "Name")
  #name    = "bastionhost"
  type    = "A"
  ttl     = "300"
  records = [aws_instance.bastionhost.public_ip]
}


resource "aws_route53_record" "elb" {
  zone_id = data.aws_route53_zone.selected.zone_id
#  name    = "${var.name}.data.aws_route53_zone.selected.name"
  name    = var.name
  type    = "CNAME"
  ttl     = "300"
  records = [aws_elb.web-elb.dns_name]
}






## Access and Security Groups

resource "aws_security_group" "bastionhost" {
  name        = "${var.name}-bastionhost-sg"
  description = "Bastionhosts"
  vpc_id      = aws_vpc.hashicorp_vpc.id
}

resource "aws_security_group_rule" "jh-ssh" {
  security_group_id = aws_security_group.bastionhost.id
  type              = "ingress"
  from_port         = 22
  to_port           = 22
  protocol          = "tcp"
  cidr_blocks       = ["0.0.0.0/0"]
}

resource "aws_security_group_rule" "jh-egress" {
  security_group_id = aws_security_group.bastionhost.id
  type              = "egress"
  from_port         = 0
  to_port           = 0
  protocol          = "-1"
  cidr_blocks       = ["0.0.0.0/0"]
}

resource "aws_security_group" "web" {
  name        = "${var.name}-web-sg"
  description = "private webserver"
  vpc_id      = aws_vpc.hashicorp_vpc.id
}

resource "aws_security_group_rule" "web-http" {
  security_group_id = aws_security_group.web.id
  type              = "ingress"
  from_port         = 80
  to_port           = 80
  protocol          = "tcp"
  cidr_blocks       = ["0.0.0.0/0"]
}

resource "aws_security_group_rule" "web-https" {
  security_group_id = aws_security_group.web.id
  type              = "ingress"
  from_port         = 443
  to_port           = 443
  protocol          = "tcp"
  cidr_blocks       = ["0.0.0.0/0"]
}

resource "aws_security_group_rule" "web-ssh" {
  security_group_id = aws_security_group.web.id
  type              = "ingress"
  from_port         = 22
  to_port           = 22
  protocol          = "tcp"
  cidr_blocks       = ["0.0.0.0/0"]
}

resource "aws_security_group_rule" "web-egress" {
  security_group_id = aws_security_group.web.id
  type              = "egress"
  from_port         = 0
  to_port           = 0
  protocol          = "-1"
  cidr_blocks       = ["0.0.0.0/0"]
}

resource "aws_security_group" "elb" {
  name        = "${var.name}-elb-sg"
  description = "elasic loadbalancer"
  vpc_id      = aws_vpc.hashicorp_vpc.id
}

resource "aws_security_group_rule" "elb-http" {
  security_group_id = aws_security_group.elb.id
  type              = "ingress"
  from_port         = 80
  to_port           = 80
  protocol          = "tcp"
  cidr_blocks       = ["0.0.0.0/0"]
}

resource "aws_security_group_rule" "elb-htts" {
  security_group_id = aws_security_group.elb.id
  type              = "ingress"
  from_port         = 443
  to_port           = 443
  protocol          = "tcp"
  cidr_blocks       = ["0.0.0.0/0"]
}

resource "aws_security_group_rule" "elb-egress" {
  security_group_id = aws_security_group.elb.id
  type              = "egress"
  from_port         = 0
  to_port           = 0
  protocol          = "-1"
  cidr_blocks       = ["0.0.0.0/0"]
}

resource "aws_security_group" "nat" {
  name        = "${var.name}-nat-sg"
  description = "nat instance"
  vpc_id      = aws_vpc.hashicorp_vpc.id
}

resource "aws_security_group_rule" "nat-http" {
  security_group_id = aws_security_group.nat.id
  type              = "ingress"
  from_port         = 80
  to_port           = 80
  protocol          = "tcp"
  cidr_blocks       = ["0.0.0.0/0"]
}

resource "aws_security_group_rule" "nat-htts" {
  security_group_id = aws_security_group.nat.id
  type              = "ingress"
  from_port         = 443
  to_port           = 443
  protocol          = "tcp"
  cidr_blocks       = ["0.0.0.0/0"]
}

resource "aws_security_group_rule" "nat-egress" {
  security_group_id = aws_security_group.nat.id
  type              = "egress"
  from_port         = 0
  to_port           = 0
  protocol          = "-1"
  cidr_blocks       = ["0.0.0.0/0"]
}

