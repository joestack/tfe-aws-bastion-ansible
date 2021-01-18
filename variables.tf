variable "aws_region" {
  description = "AWS region"
  default     = "us-east-1"
}

variable "name" {
  description = "Unique name of the deployment"
}

variable "web_node_count" {
  description = "number of worker nodes"
  default     = "3"
}

variable "instance_type" {
  description = "instance size to be used for worker nodes"
  default     = "t2.small"
}

variable "web_subnet_count" {
  description = "number of subnets to be used for working nodes"
  default     = "2"
}

variable "ssh_user" {
  description = "default ssh user to get access to an instance"
  default     = "ubuntu"
}

variable "pub_key" {
  description = "the public key to be used to access the bastion host and ansible nodes"
  default     = "joestack"
}

variable "pri_key" {
  description = "the base64 encoded private key to be used to access the bastion host and ansible nodes"
}

variable "dns_domain" {
  description = "DNS domain suffix"
  default     = "joestack.xyz"
}

variable "network_address_space" {
  description = "CIDR for this deployment"
  default     = "192.168.0.0/16"
}

locals {
  mod_az = length(
    split(",", join(", ", data.aws_availability_zones.available.names)),
  )
}

locals {
  priv_key = base64decode(var.pri_key)
}
