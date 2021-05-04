output "Bastionhost_public_IP" {
  value = "ssh ${var.ssh_user}@${aws_instance.bastionhost.public_ip}"
}

output "Bastionhost_DNS" {
  value = aws_route53_record.bastionhost.name
}

output "ELB_public_DNS" {
  value = "${aws_route53_record.elb.name}.${var.dns_domain}"
}

output "inventory" {
  value = data.template_file.ansible_skeleton.rendered
}

output "ansible_hosts" {
  value = data.template_file.ansible_web_hosts.*.rendered
}

output "web_node_ips" {
  value = aws_instance.web_nodes.*.private_ip
}

# output "ELB_AWS_internal_DNS" {
#   value = aws_elb.web-elb.dns_name
# }

