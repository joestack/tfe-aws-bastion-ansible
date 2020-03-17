terraform {
  required_version = ">= 0.12"
}

provider "aws" {
    region = var.aws_region
}

resource "aws_key_pair" "joestack_aws" {
  key_name   = "joestack_aws"
  public_key = "ssh-rsa AAAAB3NzaC1yc2EAAAADAQABAAABAQCvOp4xxCMWtSfMkO73Xv29aavZlPKFdJ3kI9CpY1Dnl0Q945TybNcFQuZ53RRvw7ccOx0CctuzDRwW3FX9rdD96htu2uoZXeeY0tB2gb3md/LpKw3I+PRJXIHwwbfpQK8rxXlmDIiPR8P7frNs/Y3z2dYxlmlE+OB4Y3hbF10vBxJUECX2AmTNDb+IBS1APJc/Sw+04aEwh2kiv5tfqhM+1bjhKxBzY/h5+H7jV0psH/TeAkr7yvY7KVwrqad+MXGvMfAwp0ziWh7BWMUeOHsCIJx9tUlLPL/5HvjeFniALXVIIrGo/kz1SI0Q5Na60iAETi1t8jlWOOPOWLe28JUL joern@Think-X1"
}

# INSTANCES

resource "aws_instance" "bastionhost" {
  ami                         = data.aws_ami.ubuntu.id
  instance_type               = "t2.micro"
  subnet_id                   = aws_subnet.dmz_subnet.id
  private_ip                  = cidrhost(aws_subnet.dmz_subnet.cidr_block, 10)
  associate_public_ip_address = "true"
  vpc_security_group_ids      = [aws_security_group.bastionhost.id]
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
    Name        = "bastionhost-${var.name}"
    TTL         = var.ttl
    Owner       = var.owner             
  }
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

# resource "aws_instance" "api_nodes" {
#   count                       = var.api_node_count
#   ami                         = data.aws_ami.ubuntu.id
#   instance_type               = var.instance_type
#   subnet_id                   = element(aws_subnet.api_subnet.*.id, count.index + 1)
#   associate_public_ip_address = "false"
#   vpc_security_group_ids      = [aws_security_group.api.id]
#   key_name                    = var.key_name

#   tags = {
#     Name        = format("api-%02d", count.index + 1)
#     TTL         = var.ttl
#     Owner       = var.owner
#   }
# }