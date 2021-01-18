output "Bastionhost_public_IP" {
  value = "ssh ${var.ssh_user}@${aws_instance.bastionhost.public_ip}"
}

output "Bastionhost_DNS" {
  value = aws_route53_record.bastionhost.name
}

output "ELB_public_DNS" {
  value = "${aws_route53_record.elb.name}.${var.dns_domain}"
}

# output "ELB_AWS_internal_DNS" {
#   value = aws_elb.web-elb.dns_name
# }

