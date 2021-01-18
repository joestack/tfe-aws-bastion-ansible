
# INSTANCES

resource "aws_instance" "bastionhost" {
  ami                         = data.aws_ami.ubuntu.id
  instance_type               = "t2.micro"
  subnet_id                   = aws_subnet.dmz_subnet.id
  private_ip                  = cidrhost(aws_subnet.dmz_subnet.cidr_block, 10)
  associate_public_ip_address = "true"
  vpc_security_group_ids      = [aws_security_group.bastionhost.id]
  key_name                    = var.pub_key

  user_data = <<-EOF
              #!/bin/bash
              echo "${local.priv_key}" >> /home/ubuntu/.ssh/id_rsa
              chown ubuntu /home/ubuntu/.ssh/id_rsa
              chgrp ubuntu /home/ubuntu/.ssh/id_rsa
              chmod 600 /home/ubuntu/.ssh/id_rsa
              apt-get update -y
              apt-get install ansible -y 
              EOF

  tags = {
    Name        = "bastionhost-${var.name}"
  }
}

resource "aws_instance" "web_nodes" {
  count                       = var.web_node_count
  ami                         = data.aws_ami.ubuntu.id
  instance_type               = var.instance_type
  subnet_id                   = element(aws_subnet.web_subnet.*.id, count.index + 1)
  associate_public_ip_address = "false"
  vpc_security_group_ids      = [aws_security_group.web.id]
  key_name                    = var.pub_key


  tags = {
    Name        = format("web-%02d", count.index + 1)
  }
}

# resource "aws_instance" "api_nodes" {
#   count                       = var.api_node_count
#   ami                         = data.aws_ami.ubuntu.id
#   instance_type               = var.instance_type
#   subnet_id                   = element(aws_subnet.api_subnet.*.id, count.index + 1)
#   associate_public_ip_address = "false"
#   vpc_security_group_ids      = [aws_security_group.api.id]
#   key_name                    = var.pub_key_n

#   tags = {
#     Name        = format("api-%02d", count.index + 1)
#   }
# }