output "Jumphost_public_IP" {
  value = aws_instance.jumphost.public_ip
}

output "Jumphost_DNS" {
  value = aws_route53_record.jumphost.name
}

output "ELB_public_DNS" {
  value = aws_route53_record.elb.name
}

output "ELB_AWS_internal_DNS" {
  value = aws_elb.web-elb.dns_name
}

